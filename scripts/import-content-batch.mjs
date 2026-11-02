import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {database} from '../backend/database.mjs';
import {validateContentBatch} from './validate-content-batch.mjs';
export const publishedDocument=r=>{const d=structuredClone(r);delete d.review;return d;};
export async function importBatch(db,batch,{activate=false,retire=[]}={}){
 const errors=validateContentBatch(batch);if(errors.length)throw Error(errors.join('\n'));
 await db.exec('begin');
 try{
  let inserted=0,skipped=0;
  const before=(await db.query('select id,current_version,active,display_order from public.cnrecipe_recipes order by id')).rows;
  for(const i of batch.ingredients){
   const old=(await db.query('select name from public.cnrecipe_ingredients where id=$1',[i.id])).rows[0];
   if(old&&old.name!==i.name)throw Error(`Ingredient conflict: ${i.id}`);
   if(!old)await db.query('insert into public.cnrecipe_ingredients(id,name) values($1,$2)',[i.id,i.name]);
  }
  for(const [order,r] of batch.recipes.entries()){
   const document=publishedDocument(r);
   const old=(await db.query('select document from public.cnrecipe_versions where recipe_id=$1 and version=$2',[r.id,r.version])).rows[0];
   if(old){
    const same=(await db.query('select $1::jsonb=$2::jsonb as same',[JSON.stringify(old.document),JSON.stringify(document)])).rows[0].same;
    if(!same)throw Error(`Immutable version conflict: ${r.id}@${r.version}`);
    skipped++;
   }else{
    await db.query('insert into public.cnrecipe_recipes(id,current_version,active,display_order) values($1,$2,false,$3) on conflict(id) do nothing',[r.id,r.version,order]);
    await db.query('insert into public.cnrecipe_versions(recipe_id,version,document) values($1,$2,$3::jsonb)',[r.id,r.version,JSON.stringify(document)]);inserted++;
   }
   if(activate)await db.query('update public.cnrecipe_recipes set current_version=$2,active=true,display_order=$3 where id=$1',[r.id,r.version,order]);
  }
  for(const id of retire){if(batch.recipes.some(r=>r.id===id))throw Error('Cannot retire a recipe in this batch');await db.query('update public.cnrecipe_recipes set active=false where id=$1',[id]);}
  await db.exec('commit');return {inserted,skipped,activation:activate?'active':'unchanged; new recipes inactive',before};
 }catch(e){await db.exec('rollback');throw e;}
}
export function releaseSQL(batch,{retire=[]}={}){
 const errors=validateContentBatch(batch);if(errors.length)throw Error(errors.join('\n'));
 if(retire.some(id=>batch.recipes.some(r=>r.id===id)))throw Error('Cannot retire current recipe');
 const payload=JSON.stringify({ingredients:batch.ingredients,recipes:batch.recipes.map(publishedDocument),retire});
 const literal="'"+payload.replaceAll("'","''")+"'";
 const body=`declare payload jsonb:=${literal}::jsonb; item jsonb; doc jsonb; retired text; position integer:=0;
 begin
 perform pg_advisory_xact_lock(hashtext('cnrecipe-classic-50-release'));
 for item in select value from jsonb_array_elements(payload->'ingredients') loop
  if exists(select 1 from public.cnrecipe_ingredients where id=item->>'id' and name<>item->>'name') then raise exception 'Ingredient identity conflict'; end if;
  insert into public.cnrecipe_ingredients(id,name) values(item->>'id',item->>'name') on conflict(id) do nothing;
 end loop;
 for doc in select value from jsonb_array_elements(payload->'recipes') loop
  if exists(select 1 from public.cnrecipe_versions where recipe_id=doc->>'id' and version=(doc->>'version')::integer and document<>doc) then raise exception 'Immutable recipe version conflict'; end if;
  insert into public.cnrecipe_recipes(id,current_version,active,display_order) values(doc->>'id',(doc->>'version')::integer,false,position) on conflict(id) do nothing;
  insert into public.cnrecipe_versions(recipe_id,version,document) values(doc->>'id',(doc->>'version')::integer,doc) on conflict(recipe_id,version) do nothing;
  update public.cnrecipe_recipes set current_version=(doc->>'version')::integer,active=true,display_order=position where id=doc->>'id';
  position:=position+1;
 end loop;
 for retired in select jsonb_array_elements_text(payload->'retire') loop update public.cnrecipe_recipes set active=false where id=retired; end loop;
 end`;
 let tag='$cnrecipe_release$';while(body.includes(tag))tag=tag.slice(0,-1)+'x$';
 return `begin;\nset constraints all deferred;\ndo ${tag}\n${body}\n${tag};\ncommit;\n`;
}

if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 const batch=JSON.parse(await readFile(process.argv[2],'utf8'));
 const errors=validateContentBatch(batch);if(errors.length)throw Error(errors.join('\n'));
 const folder=resolve('artifacts/content-import-rehearsal');await mkdir(folder,{recursive:true});
 const {db,rpc}=await database(folder+'/database');
 try{const result=await importBatch(db,batch,{activate:true,retire:['rice','bok']});await writeFile(folder+'/report.json',JSON.stringify(result,null,2));await writeFile(folder+'/catalog.json',JSON.stringify(await rpc('cnrecipe_catalog')));await writeFile(folder+'/release.sql',releaseSQL(batch,{retire:['rice','bok']}));console.log({inserted:result.inserted,skipped:result.skipped,activation:result.activation});}finally{await db.close();}
}
