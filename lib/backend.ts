import {createClient} from '@supabase/supabase-js';
import {Platform, AppState} from 'react-native';
import * as SecureStore from 'expo-secure-store';
const url=process.env.EXPO_PUBLIC_SUPABASE_URL;
const key=process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const secureStorage={getItem:async(k:string)=>Platform.OS==='web'?globalThis.localStorage?.getItem(k)??null:SecureStore.getItemAsync(k),setItem:async(k:string,v:string)=>{if(Platform.OS==='web')globalThis.localStorage?.setItem(k,v);else await SecureStore.setItemAsync(k,v)},removeItem:async(k:string)=>{if(Platform.OS==='web')globalThis.localStorage?.removeItem(k);else await SecureStore.deleteItemAsync(k)}};
export const backendConfigured=!!(url&&key);
export const supabase=backendConfigured?createClient(url!,key!,{auth:{storage:secureStorage,autoRefreshToken:true,persistSession:true,detectSessionInUrl:Platform.OS==='web'}}):null;
if(supabase&&Platform.OS!=='web')AppState.addEventListener('change',state=>state==='active'?supabase.auth.startAutoRefresh():supabase.auth.stopAutoRefresh());
export const requireBackend=()=>{if(!supabase)throw new Error('Live service is not configured. Connect Supabase to enable secure accounts and cross-device data. You can use the separate demo workspace.');return supabase};
export async function createPayment(propertyId:string,buyer:{name:string;email:string;phone:string}){const client=requireBackend();const{data,error}=await client.functions.invoke('create-payment',{body:{propertyId,buyer}});if(error)throw error;if(data.error)throw new Error(data.error);return data as {checkoutUrl:string;transactionId:string;amount:number};}
