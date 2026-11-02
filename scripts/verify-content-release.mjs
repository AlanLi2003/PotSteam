import {readFile,writeFile,mkdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {publishedDocument} from './import-content-batch.mjs';
const batchFile=process.argv[2]||'docs/content/first-50/batches/classic-50-en.json';
const out=process.argv[3]||'artifacts/classic-50-release';
const batch=JSON.parse(await readFile(batchFile,'utf8'));
const source=await readFile('web/explore/app.js','utf8');const key=source.match(/const publicKey='([^']+)'/)[1];
const api='https://mlrerdrnwuudjsnjodkp.supabase.co/functions/v1/cnrecipe';
async function get(path){const r=await fetch(api+path,{headers:{apikey:key},signal:AbortSignal.timeout(45000)});if(!r.ok)throw Error(`API ${r.status}: ${path}`);return r.json();}
const canonical=v=>Array.isArray(v)?v.map(canonical):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,canonical(v[k])])):v;
const health=await get('/v1/health');const catalog=await get('/v1/catalog?filter=All');assert.equal(catalog.recipes.length,50);
assert.deepEqual(catalog.recipes.map(r=>r.id),batch.recipes.map(r=>r.id));
let projectionCount=0;
for(const expected of batch.recipes){const remote=catalog.recipes.find(r=>r.id===expected.id);const {quotes,allergyAlerts,...document}=remote;assert.deepEqual(canonical(document),canonical(publishedDocument(expected)));
 assert.equal(quotes.length,16);for(const q of quotes){projectionCount++;assert.equal(q.recipeVersion,remote.version);assert.equal(q.ingredients.length,remote.ingredients.length);assert(q.ingredients.every(i=>Number.isFinite(i.quantity)&&i.quantity>=0&&i.display&&!/\p{Script=Han}/u.test(i.name+i.display)));}
}
assert.equal(projectionCount,800);
const old=await get('/v1/recipes/tomato?version=1');assert.equal(old.version,1);
const current=await get('/v1/recipes/tomato');assert.equal(current.version,batch.recipes.find(r=>r.id==='tomato').version);
for(const filter of ['Quick','Beginner','Vegetarian','Noodles']){const r=await get('/v1/catalog?filter='+filter);assert(r.recipes.length>0);}
const offline=JSON.parse(await readFile('ios/CNrecipe/Content/catalog.json','utf8'));assert.deepEqual(canonical(offline),canonical(catalog));
const report={date:'2026-11-02',health,recipes:50,projectionCount,publishedDocumentsMatch:true,offlineCatalogMatch:true,oldVersionRetained:true,filtersVerified:['Quick','Beginner','Vegetarian','Noodles'],batchSHA256:createHash('sha256').update(await readFile(batchFile)).digest('hex'),catalogVersion:catalog.catalogVersion};
await mkdir(out,{recursive:true});await writeFile(out+'/api-verification.json',JSON.stringify(report,null,2)+'\n');await writeFile(out+'/production-catalog.json',JSON.stringify(catalog)+'\n');console.log(report);
