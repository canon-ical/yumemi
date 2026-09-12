const inputs=new WeakMap();
class SealRequest {toJSON(){throw new Error('Sealed input cannot be serialized');}}
export function forStaff(value){const request=Object.freeze(new SealRequest());inputs.set(request,value);return request;}
export async function encrypt(request,base64Key){
 if(!inputs.has(request))throw new Error('Invalid sealed input');
 const raw=Uint8Array.from(atob(base64Key),c=>c.charCodeAt(0));
 if(raw.length!==32)throw new Error('Invalid sealing key');
 const key=await crypto.subtle.importKey('raw',raw,'AES-GCM',false,['encrypt']);
 const nonce=crypto.getRandomValues(new Uint8Array(12));
 const cipher=new Uint8Array(await crypto.subtle.encrypt({name:'AES-GCM',iv:nonce},key,new TextEncoder().encode(inputs.get(request))));
 const bytes=new Uint8Array(1+nonce.length+cipher.length);bytes[0]=1;bytes.set(nonce,1);bytes.set(cipher,13);
 const hex=value=>Array.from(value,b=>b.toString(16).padStart(2,'0')).join('');
 const fingerprint=new Uint8Array(await crypto.subtle.digest('SHA-256',raw));
 return {hex:hex(bytes),key_id:'sha256:'+hex(fingerprint)};
}
