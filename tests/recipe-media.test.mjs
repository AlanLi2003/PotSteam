import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {database} from '../backend/database.mjs';
import {importBatch,publishedDocument} from '../scripts/import-content-batch.mjs';
import {validateContentBatch} from '../scripts/validate-content-batch.mjs';
const read=async p=>JSON.parse(await readFile(new URL('../'+p,import.meta.url),'utf8'));
const original=await read('docs/content/first-50/batches/classic-50-en.json');
const photos=await read('docs/content/first-50/batches/classic-50-en-photos.json');
const imageRights=await read('docs/content/first-50/photo-rights.json');
const icons=await read('ios/CNrecipe/Content/ingredient-icons.json');
const comparable=r=>{const d=publishedDocument(r);delete d.version;delete d.imageKey;delete d.bundledImage;for(const i of [...d.ingredients,...d.steps])delete i.id;return d;};
test('50 food images are real local JPEG assets with generated-source provenance and unique hashes',async()=>{
 assert.equal(photos.recipes.length,50);assert.deepEqual(validateContentBatch(photos),[]);assert.equal(imageRights.length,50);const hashes=new Set();
 for(const [index,r] of photos.recipes.entries()){
  const rights=imageRights[index];assert.equal(rights.recipeId,r.id);assert.equal(rights.generator,'image_gen');assert.equal(rights.imageKey,r.imageKey);
  const bytes=await readFile(new URL('../'+rights.file,import.meta.url));assert(bytes.length<5_000_000&&bytes.length>20_000);assert.equal(bytes.readUInt16BE(0),0xffd8);assert.equal(bytes.readUInt16BE(bytes.length-2),0xffd9);
  assert.equal(createHash('sha256').update(bytes).digest('hex'),rights.sha256);hashes.add(rights.sha256);
  assert.match(r.bundledImage,/photo-v[1-9][0-9]*\.jpg$/);assert.equal(r.version,original.recipes[index].version+1);assert.deepEqual(comparable(r),comparable(original.recipes[index]));
 }
 assert.equal(hashes.size,50,'Different dishes must not share the same photo');
});
test('all ingredient and equipment identities and exact names map to valid PNG icons',async()=>{
 const normalize=s=>s.toLowerCase().replaceAll('-',' ').trim().split(/\s+/).join(' ');
 let equipmentCount=new Set();
 for(const r of photos.recipes){for(const i of r.ingredients){assert(icons[i.ingredientId],i.name);assert.equal(icons[i.ingredientId],icons['name:'+normalize(i.name)]);}
  for(const e of r.equipment){equipmentCount.add(e.id);assert(icons['equipment:'+e.id],e.name);assert.equal(icons['equipment:'+e.id],icons['name:'+normalize(e.name)]);}
 }
 assert.equal(equipmentCount.size,20);
 for(const asset of new Set(Object.values(icons))){assert.notEqual(asset,'ingredient');const p=new URL('../ios/CNrecipe/Content/icons/'+asset+'.png',import.meta.url);const b=await readFile(p);assert.equal(b.subarray(1,4).toString(),'PNG');assert(b.readUInt32BE(16)>0&&b.readUInt32BE(20)>0);}
});
test('photo revisions publish idempotently and retain old title-cover versions',async()=>{
 const legacy=await read('tests/fixtures/legacy-catalog.json');const {db,rpc}=await database(undefined,legacy);
 try{
  await importBatch(db,original,{activate:true,retire:['rice','bok']});
  const result=await importBatch(db,photos,{activate:true});assert.equal(result.inserted,50);
  const catalog=await rpc('cnrecipe_catalog');assert.equal(catalog.recipes.length,50);assert.equal(catalog.recipes.reduce((n,r)=>n+r.quotes.length,0),800);
  assert.equal((await rpc('cnrecipe_recipe',{p_id:'tomato',p_version:2})).bundledImage,'classic-01.jpg');
  assert.equal((await rpc('cnrecipe_recipe',{p_id:'tomato'})).version,3);
  const repeated=await importBatch(db,photos,{activate:true});assert.equal(repeated.inserted,0);assert.equal(repeated.skipped,50);
  assert.equal((await db.query('select count(*)::int as n from public.cnrecipe_versions')).rows[0].n,106);
 }finally{await db.close();}
});
