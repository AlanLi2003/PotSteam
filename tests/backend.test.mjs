import {readFileSync} from 'node:fs';
const legacyCatalog=JSON.parse(readFileSync(new URL('./fixtures/legacy-catalog.json',import.meta.url),'utf8'));
import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {database} from '../backend/database.mjs';
let fixture;const alice='aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa',bob='bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb';
before(async()=>{fixture=await database(undefined,legacyCatalog);});after(async()=>{await fixture.db.close();});
const sync=(ops=[],owner=alice,cursor=0)=>fixture.rpc('cnrecipe_sync',{p_cursor:cursor,p_operations:ops,p_timezone:'Asia/Shanghai'},owner);
const inventory=(name='Tomatoes')=>({name,qty:'2',group:'Produce',storage:'Fridge',type:'Best before',added:'2026-01-01',until:'2026-12-31'});
const op=(kind,id,data,extra={})=>({id:randomUUID(),kind,entityId:id,action:'put',baseRevision:0,data,...extra});
test('catalog preserves approved order; server supplies 16 portion/unit projections',async()=>{
 const c=await fixture.rpc('cnrecipe_catalog');assert.equal(c.recipes.length,6);assert.equal(c.recipes[0].id,'tomato');
 const r=c.recipes[0];assert.equal(r.quotes.length,16);
 assert.deepEqual((await fixture.rpc('cnrecipe_catalog',{p_allergens:['Eggs']})).recipes[0].allergyAlerts,['Eggs']);
 const q=r.quotes.find(q=>q.servings===4&&q.units==='Metric');assert.equal(q.ingredients[0].quantity,4);assert.equal(q.ingredients[3].display,'30 mL');
 assert.equal((await fixture.rpc('cnrecipe_catalog',{p_query:'番茄'})).recipes.length,1);
 assert.equal((await fixture.rpc('cnrecipe_catalog',{p_filter:'Pantry',p_pantry:['Eggs']})).recipes.length,2);
 assert.equal((await fixture.rpc('cnrecipe_catalog',{p_filter:'Pantry',p_pantry:['Eggs carton']})).recipes.length,0);
});
test('inventory CRUD, idempotent retry, causal offline edits and tombstones',async()=>{
 const a=op('inventory','tomatoes',inventory());let r=await sync([a]);assert.equal(r.receipts[0].status,'applied');const revision=r.entities[0].revision;
 r=await sync([a]);assert.equal(r.receipts[0].duplicate,true);assert.equal(r.entities[0].revision,revision);
 const b=op('inventory','tomatoes',inventory('Garden tomatoes'),{dependsOn:a.id});r=await sync([b]);assert.equal(r.receipts[0].status,'applied');
 const del=op('inventory','tomatoes',{}, {action:'delete',dependsOn:b.id});r=await sync([del]);assert.equal(r.receipts[0].entities[0].deleted,true);
});
test('stale revisions conflict without losing remote data, batches are isolated by account',async()=>{
 let r=await sync([op('inventory','milk',inventory('Milk'))]);assert.equal(r.receipts[0].status,'applied');
 r=await sync([op('inventory','milk',inventory('Overwritten'))]);assert.equal(r.receipts[0].status,'conflict');assert.equal(r.receipts[0].entities[0].data.name,'Milk');
 assert.equal((await sync([],bob)).entities.length,0);
 await assert.rejects(fixture.rpc('cnrecipe_sync'),/permission denied/);
});
test('server rejects invalid dates while valid edits in same batch survive',async()=>{
 const r=await sync([op('inventory','invalid', {...inventory(),until:'2025-01-01'}),op('inventory','valid',inventory('Rice'))]);
 assert.deepEqual(r.receipts.map(r=>r.status),['rejected','applied']);
});
test('recipe shopping add merges canonical ingredients; dependent toggle resolves provisional ID',async()=>{
 const a=op('shopping','provisional', {name:'Eggs',ingredientId:'eggs',checked:false},{action:'shopping.add'});
 const b=op('shopping','provisional', {name:'Eggs',ingredientId:'eggs',checked:true},{dependsOn:a.id});
 let r=await sync([a,b]);assert.deepEqual(r.receipts.map(r=>r.status),['applied','applied']);assert.equal(r.receipts[1].entities[0].data.checked,true);
 const c=op('shopping','from-recipe',{recipeId:'tomato',recipeVersion:1,servings:4,units:'Metric'},{action:'shopping.recipe'});
 r=await sync([c]);assert.equal(r.receipts[0].entities.length,5);assert.equal(r.receipts[0].entities.find(e=>e.data.ingredientId==='eggs').data.checked,true);
});
test('saved cooking history owns an immutable server version snapshot',async()=>{
 const d={recipeId:'tomato',recipeVersion:1,rating:5,note:'Good!',completedAt:new Date().toISOString(),recipeSnapshot:{steps:[]}};
 let r=await sync([op('record','record-one',d)]);assert.equal(r.receipts[0].status,'applied');const e=r.receipts[0].entities[0];assert.equal(e.data.recipeSnapshot.steps.length,4);
 r=await sync([op('record','record-one',d,{baseRevision:e.revision})]);assert.equal(r.receipts[0].status,'rejected');
 await assert.rejects(fixture.db.query("update public.cnrecipe_versions set document=document where recipe_id='tomato'"),/immutable/);
});
test('actual RLS blocks foreign reads and writes, and client catalog edits',async()=>{
 await fixture.db.exec('begin;set local role authenticated');
 try {
  await fixture.db.query("select set_config('request.jwt.claim.sub',$1,true)",[bob]);
  assert.equal((await fixture.db.query('select * from public.cnrecipe_user_entities where owner_id=$1',[alice])).rows.length,0);
  await assert.rejects(fixture.db.query('insert into public.cnrecipe_user_entities(owner_id,kind,id,data) values($1,$2,$3,$4)',[alice,'inventory','attack',JSON.stringify(inventory())]),/row-level security/);
 }finally{await fixture.db.exec('rollback');}
 await fixture.db.exec('begin;set local role anon');
 try{await assert.rejects(fixture.db.query("update public.cnrecipe_recipes set active=false"),/permission denied/);}finally{await fixture.db.exec('rollback');}
});
test('publishing v2 changes current recipes while v1 cooking history stays immutable',async()=>{
 const original=await fixture.rpc('cnrecipe_recipe',{p_id:'tomato',p_version:1});
 const {rows}=await fixture.db.query("select document from public.cnrecipe_versions where recipe_id='tomato' and version=1");
 const next=structuredClone(rows[0].document);next.version=2;next.steps[0].instruction='A revised instruction for new sessions.';
 await fixture.db.query('insert into public.cnrecipe_versions(recipe_id,version,document) values($1,$2,$3::jsonb)',['tomato',2,JSON.stringify(next)]);
 await fixture.db.query("update public.cnrecipe_recipes set current_version=2 where id='tomato'");
 const current=await fixture.rpc('cnrecipe_recipe',{p_id:'tomato'});assert.equal(current.version,2);assert.ok(current.quotes.every(q=>q.recipeVersion===2));
 assert.equal((await fixture.rpc('cnrecipe_recipe',{p_id:'tomato',p_version:1})).steps[0].instruction,original.steps[0].instruction);
 const result=await sync([op('record','old-session-after-publication',{recipeId:'tomato',recipeVersion:1,rating:4,note:'Started before the update',completedAt:new Date().toISOString()})]);
 assert.equal(result.receipts[0].status,'applied');assert.equal(result.receipts[0].entities[0].data.recipeSnapshot.version,1);
});
