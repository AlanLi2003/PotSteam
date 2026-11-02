import {PGlite} from '@electric-sql/pglite';
import {readFile} from 'node:fs/promises';
export const seed=JSON.parse(await readFile(new URL('./seeds/catalog.json',import.meta.url),'utf8'));
const literal=v=>"'"+String(v).replaceAll("'","''")+"'";
export function seedSQL(contentSeed=seed) {
 return 'begin;\n'+contentSeed.ingredients.map(i=>`insert into public.cnrecipe_ingredients(id,name) values(${literal(i.id)},${literal(i.name)});`).join('\n')+'\n'+contentSeed.recipes.map((r,n)=>`insert into public.cnrecipe_recipes(id,current_version,display_order) values(${literal(r.id)},${r.version},${n});\ninsert into public.cnrecipe_versions(recipe_id,version,document) values(${literal(r.id)},${r.version},${literal(JSON.stringify(r))}::jsonb);`).join('\n')+'\ncommit;\n';
}
export async function database(path,contentSeed=seed) {
 const db=new PGlite(path);
 const {rows}=await db.query("select to_regclass('public.cnrecipe_recipes') as present");
 if(!rows[0].present) {
  // Local integration fixture only. Hosted Supabase supplies auth schema and roles.
  await db.exec(`create role anon nologin;create role authenticated nologin;create schema auth;create table auth.users(id uuid primary key);grant usage on schema auth to anon,authenticated;create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;grant execute on function auth.uid() to anon,authenticated;`);
  await db.exec(await readFile(new URL('./schema.sql',import.meta.url),'utf8'));
  await db.exec(seedSQL(contentSeed));
 }
 // Each call uses an actual database role and owner context; never share it across requests.
 let tail=Promise.resolve();
 const rpc=(name,args={},owner=null)=>{
  const run=async()=>{
   await db.exec('begin');
   try {
    if(owner) await db.query('insert into auth.users(id) values($1) on conflict do nothing',[owner]);
    await db.exec('set local role '+(owner?'authenticated':'anon'));
    await db.query("select set_config('request.jwt.claim.sub',$1,true)",[owner||'']);
    const keys=Object.keys(args);
    if(!['cnrecipe_catalog','cnrecipe_recipe','cnrecipe_sync'].includes(name)||keys.some(k=>!/^p_[a-z_]+$/.test(k))) throw Error('Unknown RPC');
    const result=await db.query(`select public.${name}(${keys.map((k,n)=>`${k} => $${n+1}`).join(',')}) as value`,Object.values(args).map(v=>v!==null&&typeof v==='object'?JSON.stringify(v):v));
    await db.exec('commit');return result.rows[0].value;
   }catch(e){await db.exec('rollback');throw e;}
  };
  const p=tail.then(run);tail=p.catch(()=>{});return p;
 };
 return {db,rpc};
}
