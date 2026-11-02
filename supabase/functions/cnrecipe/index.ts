import {createAPI} from './api.mjs';
const url=Deno.env.get('SUPABASE_URL')!;
// The built-in anon key is public; RLS and the user's JWT authorize every RPC.
const key=Deno.env.get('SUPABASE_ANON_KEY')!;
Deno.serve(createAPI({
 authenticate:async(header:string)=>{
  if(!/^Bearer [A-Za-z0-9._-]+$/.test(header))return null;
  const response=await fetch(url+'/auth/v1/user',{headers:{apikey:key,authorization:header}});
  return response.ok?(await response.json()).id:null;
 },
 rpc:async(name:string,args:unknown,_user:unknown,authorization:string|null)=>{
  const response=await fetch(url+'/rest/v1/rpc/'+name,{method:'POST',headers:{apikey:key,authorization:authorization||'Bearer '+key,'content-type':'application/json'},body:JSON.stringify(args)});
  const body=await response.json();if(!response.ok)throw Object.assign(new Error(body.message||'Database request failed'),{code:body.code});return body;
 }
}));
