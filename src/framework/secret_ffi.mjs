const inputs=new WeakMap();
class SecretRequest { toJSON(){ throw new Error('Secret input cannot be serialized'); } }

// Keep the request opaque in Gleam.  The runtime consumes it at the storage
// boundary, where the application supplies the HMAC implementation/key.
export function hmac(value) {
 const request=Object.freeze(new SecretRequest());
 inputs.set(request,String(value));
 return request;
}

export function value(request) {
 if(!inputs.has(request)) throw new Error('Invalid secret input');
 return inputs.get(request);
}
