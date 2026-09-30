import * as ImagePicker from 'expo-image-picker';
import {supabase} from './backend';
export async function pickPhotos(multiple=true,live=false):Promise<string[]>{
 const permission=await ImagePicker.requestMediaLibraryPermissionsAsync();if(!permission.granted)throw Error('Photo access is needed to choose property images. You can enable it in device settings.');
 const result=await ImagePicker.launchImageLibraryAsync({mediaTypes:['images'],allowsMultipleSelection:multiple,selectionLimit:multiple?10:1,quality:.85,base64:true});if(result.canceled)return [];
 const files:string[]=[];
 for(const asset of result.assets){if(asset.fileSize&&asset.fileSize>10*1024*1024)throw Error('Each image must be smaller than 10 MB.');if(asset.mimeType&&!['image/jpeg','image/png','image/webp','image/jpg'].includes(asset.mimeType))throw Error('Please choose JPG, PNG, or WebP images.');if(!asset.base64)throw Error('This image could not be read. Please choose another.');
  const mime=asset.mimeType||'image/jpeg';let uri=`data:${mime};base64,${asset.base64}`;
  if(live){if(!supabase)throw Error('Image storage is not configured.');const{data:{user}}=await supabase.auth.getUser();if(!user)throw Error('Please sign in before uploading.');const buffer=Uint8Array.from(atob(asset.base64),c=>c.charCodeAt(0));const ext=mime.split('/')[1];const path=`${user.id}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;const{error}=await supabase.storage.from('property-images').upload(path,buffer,{contentType:mime,upsert:false});if(error)throw error;uri=supabase.storage.from('property-images').getPublicUrl(path).data.publicUrl;}
  files.push(uri);
 }
 return files;
}
