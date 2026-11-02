// Shared HTTP contract for the hosted Edge Function and local integration server.
// rpc always runs as anon or as the verified user, never with a service key.
export function createAPI({rpc,authenticate}) {
 const headers={'content-type':'application/json; charset=utf-8','access-control-allow-origin':'*','access-control-allow-headers':'authorization,apikey,content-type','access-control-allow-methods':'GET,POST,OPTIONS','cache-control':'no-store','x-content-type-options':'nosniff'};
 const json=(body,status=200)=>new Response(JSON.stringify(body),{status,headers});
 return async request=>{
  if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
  try {
   const url=new URL(request.url),path=url.pathname.replace(/^\/(?:functions\/v1\/)?cnrecipe(?=\/|$)/,'');
   if(path==='/v1/health'&&request.method==='GET')return json({service:'CNrecipe',apiVersion:1});
   const authorization=request.headers.get('authorization');
   const user=authorization?await authenticate(authorization):null;
   if(authorization&&!user)return json({error:'Session expired. Sign in again.'},401);
   if(request.method==='GET'&&path==='/v1/catalog') {
    const q=url.searchParams.get('q')||'',filter=url.searchParams.get('filter')||'All';
    const pantry=(url.searchParams.get('pantry')||'').split('|').filter(Boolean),allergens=(url.searchParams.get('allergens')||'').split('|').filter(Boolean);
    if(q.length>180||pantry.length>500)return json({error:'Search input is too long'},400);
    return json(await rpc('cnrecipe_catalog',{p_query:q,p_filter:filter,p_pantry:pantry,p_allergens:allergens},user,authorization));
   }
   const match=path.match(/^\/v1\/recipes\/([a-z0-9-]{1,100})$/);
   if(request.method==='GET'&&match){
    const version=url.searchParams.get('version');if(version&&!/^[1-9]\d{0,5}$/.test(version))return json({error:'Invalid recipe version'},400);
    return json(await rpc('cnrecipe_recipe',{p_id:match[1],p_version:version?Number(version):null},user,authorization));
   }
   if(request.method==='POST'&&path==='/v1/sync') {
    if(!user)return json({error:'Sign in to sync'},401);
    const body=await request.text();if(body.length>512000)return json({error:'Sync batch too large'},413);
    let b;try{b=JSON.parse(body);}catch{return json({error:'Invalid JSON'},400);}
    if(!Number.isSafeInteger(b.cursor)||b.cursor<0||!Array.isArray(b.operations)||b.operations.length>100||typeof b.timezone!=='string')return json({error:'Invalid sync batch'},400);
    for(const op of b.operations)if(!op||typeof op.id!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(op.id))return json({error:'Invalid operation ID'},400);
    return json(await rpc('cnrecipe_sync',{p_cursor:b.cursor,p_operations:b.operations,p_timezone:b.timezone},user,authorization));
   }
   return json({error:'Route not found'},404);
  }catch(e){return json({error:e.code==='P0002'?'Recipe not found':e.message||'Request failed'},e.code==='P0002'?404:400);}
 };
}
