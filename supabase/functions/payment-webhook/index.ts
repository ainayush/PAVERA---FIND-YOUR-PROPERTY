import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
const encoder=new TextEncoder();
async function validSignature(body:string,signature:string,secret:string){if(!/^[a-f\d]{64}$/i.test(signature))return false;const key=await crypto.subtle.importKey('raw',encoder.encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);const bytes=new Uint8Array(signature.match(/.{2}/g)!.map(h=>parseInt(h,16)));return crypto.subtle.verify('HMAC',key,bytes,encoder.encode(body))}
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST')return new Response('Method not allowed',{status:405});
 const secret=Deno.env.get('RAZORPAY_WEBHOOK_SECRET');if(!secret)return new Response('Webhook configuration required',{status:503});
 const raw=await req.text();if(raw.length>1000000)return new Response('Payload too large',{status:413});
 if(!await validSignature(raw,req.headers.get('x-razorpay-signature')||'',secret))return new Response('Invalid signature',{status:401});
 const db=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
 try{
  const event=JSON.parse(raw);const link=event.payload?.payment_link?.entity;const payment=event.payload?.payment?.entity;const refund=event.payload?.refund?.entity;
  let id:string|undefined;let status:string|undefined;let paymentId:string|undefined=payment?.id;let amount:number|undefined;
  if(event.event==='payment_link.paid'&&link?.status==='paid'&&link.currency==='INR'){id=link.reference_id;status='Successful';amount=link.amount_paid;paymentId=payment?.id||link.payments?.[0]?.payment_id;}
  else if(['payment_link.cancelled','payment_link.expired'].includes(event.event)&&link){id=link.reference_id;status='Failed';amount=link.amount;}
  else if(event.event==='refund.processed'&&refund){const{data:p}=await db.from('payments').select('*').eq('gateway_payment_id',refund.payment_id).single();if(p&&refund.amount===p.amount){id=p.id;status='Refunded';amount=p.amount;paymentId=refund.payment_id;}}
  if(!id||!status||!amount)return new Response('Ignored',{status:200});
  const{data:p}=await db.from('payments').select('*').eq('id',id).single();if(!p||p.amount!==amount||link&&p.gateway_order_id!==link.id)return new Response('Payment mismatch',{status:422});
  const eventId=req.headers.get('x-razorpay-event-id');if(!eventId)return new Response('Missing event identifier',{status:400});
  const{error}=await db.rpc('apply_payment_event',{event_id:eventId,payment_id:id,next_status:status,paid_id:paymentId||null,paid_method:payment?.method||null,expected_amount:amount});if(error)throw error;
  return new Response('Accepted',{status:200});
 }catch(e){console.error('Verified payment event failed',e instanceof Error?e.message:'Unknown error');return new Response('Unable to apply event',{status:500})}
});
