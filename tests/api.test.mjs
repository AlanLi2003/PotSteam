import {readFileSync} from 'node:fs';
const legacyCatalog=JSON.parse(readFileSync(new URL('./fixtures/legacy-catalog.json',import.meta.url),'utf8'));
import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {database} from '../backend/database.mjs';
import {createAPI} from '../backend/api.mjs';
let fixture,api;before(async()=>{fixture=await database(undefined,legacyCatalog);api=createAPI({rpc:fixture.rpc,authenticate:async h=>h==='Bearer alice'?'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa':null});});after(async()=>fixture.db.close());
const req=(path,init)=>api(new Request('http://localhost'+path,init));
test('public catalog, filters, versioned detail and errors use real database',async()=>{
 let r=await req('/v1/catalog?q=tomato');assert.equal(r.status,200);assert.equal((await r.json()).recipes[0].id,'tomato');
 r=await req('/v1/recipes/no-such-recipe');assert.equal(r.status,404);
 r=await req('/v1/catalog?filter=invalid');assert.equal(r.status,400);
 r=await req('/v1/recipes/tomato?version=1');assert.equal((await r.json()).quotes.length,16);
});
test('private sync rejects missing, expired and malformed credentials/bodies',async()=>{
 assert.equal((await req('/v1/sync',{method:'POST'})).status,401);
 assert.equal((await req('/v1/sync',{method:'POST',headers:{authorization:'Bearer expired'}})).status,401);
 assert.equal((await req('/v1/sync',{method:'POST',headers:{authorization:'Bearer alice'},body:'bad'})).status,400);
 const r=await req('/v1/sync',{method:'POST',headers:{authorization:'Bearer alice'},body:JSON.stringify({cursor:0,operations:[],timezone:'Asia/Shanghai'})});assert.equal(r.status,200);assert.deepEqual((await r.json()).entities,[]);
});
