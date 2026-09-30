import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const site=Deno.env.get('APP_ORIGIN')||'';
const cors={'Access-Control-Allow-Origin':site,'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS','Vary':'Origin'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:cors});if(req.method!=='POST')return json({error:'Method not allowed'},405);
 if(req.headers.get('origin')&&req.headers.get('origin')!==site)return json({error:'Origin not allowed'},403);
 const url=Deno.env.get('SUPABASE_URL'),service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),keyId=Deno.env.get('RAZORPAY_KEY_ID'),secret=Deno.env.get('RAZORPAY_KEY_SECRET');
 if(!url||!service||!keyId||!secret||!site.startsWith('https://'))return json({error:'Payments require server-side gateway configuration.'},503);
 const db=createClient(url,service);const token=req.headers.get('authorization')?.replace(/^Bearer\s+/i,'');if(!token)return json({error:'Authentication required'},401);
 const{data:{user},error:authError}=await db.auth.getUser(token);if(authError||!user||!user.email_confirmed_at)return json({error:'A verified account is required'},401);
 try{
  const body=await req.json();const {propertyId,buyer}=body;
  if(typeof propertyId!=='string'||propertyId.length>100||typeof buyer?.name!=='string'||buyer.name.trim().length<2||buyer.name.length>100||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(buyer.email)||!/^(\+91)?[6-9]\d{9}$/.test(buyer.phone.replace(/[\s-]/g,'')))return json({error:'Invalid booking details'},422);
  const{data:p,error}=await db.from('properties').select('*').eq('id',propertyId).single();if(error||!p)return json({error:'Property not found'},404);
  if(!['For Sale','For Rent'].includes(p.status)||!p.verified||p.owner_id===user.id||p.details.demo)return json({error:'This listing is not available for a verified booking.'},422);
  const amount=Math.round(Number(p.details.bookingAmount)*100);if(!Number.isSafeInteger(amount)||amount<100||amount>10000000)return json({error:'The seller must configure a valid booking amount.'},422);
  const{data:prior}=await db.from('payments').select('*').eq('buyer_id',user.id).eq('property_id',propertyId).eq('status','Pending').maybeSingle();
  if(prior?.checkout_url)return json({checkoutUrl:prior.checkout_url,transactionId:prior.id,amount:prior.amount});
  if(prior)return json({error:'A payment is being prepared. Please wait and check payment history.'},409);
  const{count}=await db.from('payments').select('id',{head:true,count:'exact'}).eq('buyer_id',user.id).gte('created_at',new Date(Date.now()-60000).toISOString());if((count||0)>=3)return json({error:'Too many payment attempts. Please wait a minute.'},429);
  const id=crypto.randomUUID();const{error:insertError}=await db.from('payments').insert({id,property_id:propertyId,buyer_id:user.id,seller_id:p.owner_id,property_title:p.title,buyer_name:buyer.name.trim(),seller_name:p.details.seller,amount,status:'Pending'});if(insertError)return json({error:'A booking may already be in progress. Please check your payment history.'},409);
  const gateway=await fetch('https://api.razorpay.com/v1/payment_links/',{method:'POST',headers:{Authorization:`Basic ${btoa(`${keyId}:${secret}`)}`,'Content-Type':'application/json'},body:JSON.stringify({amount,currency:'INR',accept_partial:false,reference_id:id,description:`Pavera booking: ${p.title}`.slice(0,200),customer:{name:buyer.name,email:buyer.email,contact:buyer.phone},notify:{sms:false,email:false},reminder_enable:false,expire_by:Math.floor(Date.now()/1000)+1800,notes:{pavera_transaction_id:id,property_id:propertyId},callback_url:`${site}/?payment=${id}`,callback_method:'get'})});
  const result=await gateway.json();if(!gateway.ok){await db.from('payments').update({status:'Failed'}).eq('id',id);return json({error:'The secure gateway could not create this booking. Please try again later.'},502)}
  const{error:saveError}=await db.from('payments').update({gateway_order_id:result.id,checkout_url:result.short_url}).eq('id',id);if(saveError)throw saveError;
  return json({checkoutUrl:result.short_url,transactionId:id,amount});
 }catch(e){console.error('Payment initialization failed',e instanceof Error?e.message:'Unknown error');return json({error:'Unable to prepare a payment. Check payment history before trying again.'},500)}
});
