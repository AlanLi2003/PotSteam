import {readFileSync} from 'node:fs';
const legacyCatalog=JSON.parse(readFileSync(new URL('./fixtures/legacy-catalog.json',import.meta.url),'utf8'));
import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {database} from '../backend/database.mjs';
import {importBatch,releaseSQL,publishedDocument} from '../scripts/import-content-batch.mjs';
import {validateContentBatch} from '../scripts/validate-content-batch.mjs';
const batch=JSON.parse(await readFile(new URL('../docs/content/first-50/batches/classic-50-en.json',import.meta.url)));
let fixture,baseline;
before(async()=>{fixture=await database(undefined,legacyCatalog);baseline=(await fixture.db.query('select count(*)::int as n from public.cnrecipe_versions')).rows[0].n;});
after(async()=>{await fixture.db.close();});
test('complete English batch activates exactly 50 without overwriting old versions',async()=>{
 assert.deepEqual(validateContentBatch(batch),[]);
 const r=await importBatch(fixture.db,batch,{activate:true,retire:['rice','bok']});assert.equal(r.inserted,50);
 const c=await fixture.rpc('cnrecipe_catalog');assert.equal(c.recipes.length,50);assert.deepEqual(c.recipes.map(r=>r.id),batch.recipes.map(r=>r.id));
 assert.equal((await fixture.db.query('select count(*)::int as n from public.cnrecipe_versions')).rows[0].n,baseline+50);
 assert.equal((await fixture.rpc('cnrecipe_recipe',{p_id:'tomato',p_version:1})).version,1);
 assert(c.recipes.every(r=>!r.demo&&!('review' in r)));
});
test('all 800 projections preserve ingredient identities and meaningful quantities',async()=>{
 const c=await fixture.rpc('cnrecipe_catalog');let count=0;
 for(const r of c.recipes){assert.equal(r.quotes.length,16);const source=new Map(r.ingredients.map(i=>[i.id,i]));
  for(const q of r.quotes){count++;assert.equal(q.recipeVersion,r.version);assert.equal(q.ingredients.length,r.ingredients.length);
   for(const i of q.ingredients){assert.equal(i.ingredientId,source.get(i.id).ingredientId);assert(Number.isFinite(i.quantity));assert(!/\p{Script=Han}/u.test(i.name+i.display));assert(i.display.trim());
    if(source.get(i.id).quantityMode){assert.equal(i.quantity,0);assert(['To taste','As needed'].includes(i.display));}else assert(i.quantity>0,`${r.name}: ${i.display}`);
   }
  }
 }
 assert.equal(count,800);
 const saltChicken=c.recipes.find(r=>r.chineseName==='客家盐焗鸡');
 const salt=q=>q.ingredients.find(i=>i.ingredientId==='salt-bed').quantity;
 assert.equal(salt(saltChicken.quotes.find(q=>q.servings===1&&q.units==='Metric')),3000);
 assert.equal(salt(saltChicken.quotes.find(q=>q.servings===8&&q.units==='Metric')),6000);
});
test('repeat import and generated SQL are idempotent; conflicts do not overwrite',async()=>{
 const r=await importBatch(fixture.db,batch,{activate:true,retire:['rice','bok']});assert.equal(r.inserted,0);assert.equal(r.skipped,50);
 await fixture.db.exec(releaseSQL(batch,{retire:['rice','bok']}));assert.equal((await fixture.rpc('cnrecipe_catalog')).recipes.length,50);
 const changed=structuredClone(batch);changed.recipes[0].steps[0].instruction+=' Changed.';
 await assert.rejects(importBatch(fixture.db,changed),/Immutable version conflict/);
 assert.deepEqual((await fixture.db.query('select document from public.cnrecipe_versions where recipe_id=$1 and version=2',['tomato'])).rows[0].document,publishedDocument(batch.recipes[0]));
});
test('late conflicts roll back newly inserted ingredients and malformed content is rejected before writes',async()=>{
 const bad=structuredClone(batch);bad.ingredients.push({id:'rollback-only-ingredient',name:'Rollback only ingredient'});bad.recipes.at(-1).minutes++;
 await assert.rejects(importBatch(fixture.db,bad),/Immutable version conflict/);
 assert.equal((await fixture.db.query("select * from public.cnrecipe_ingredients where id='rollback-only-ingredient'")).rows.length,0);
 const chinese=structuredClone(batch);chinese.recipes[0].steps[0].instruction='中文正文';assert(validateContentBatch(chinese).some(e=>e.includes('English text required')));
 const missing=structuredClone(batch);missing.recipes[0].ingredients[0].metricQuantity=null;assert(validateContentBatch(missing).length);
 const asNeeded=structuredClone(batch);asNeeded.recipes[0].ingredients[0].metricQuantity=0;assert(validateContentBatch(asNeeded).length);
});
