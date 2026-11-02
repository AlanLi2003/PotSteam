import {readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawnSync} from 'node:child_process';
const seed=JSON.parse(await readFile(new URL('../backend/seeds/catalog.json',import.meta.url),'utf8'));
const project='mlrerdrnwuudjsnjodkp',base=`https://${project}.supabase.co/storage/v1/object/public/recipe-images/`;
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
for(const r of seed.recipes){
 const path=new URL('../ios/CNrecipe/Web/assets/'+r.bundledImage,import.meta.url),bytes=await readFile(path);
 const response=await fetch(base+r.imageKey);
 if(response.ok){if(sha(Buffer.from(await response.arrayBuffer()))!==sha(bytes))throw Error(`Immutable image differs: ${r.imageKey}; create a new content version.`);console.log(`${r.id}: already verified`);continue}
 if(![400,404].includes(response.status))throw Error(`Cannot check image (${response.status})`);
 const result=spawnSync('npx',['supabase','storage','cp',path.pathname,'ss:///recipe-images/'+r.imageKey,'--project-ref',project,'--linked','--experimental','--content-type','image/jpeg','--cache-control','public,max-age=31536000,immutable'],{stdio:'inherit'});
 if(result.status!==0)throw Error('Image upload failed; inspect the CLI error above');
 const check=await fetch(base+r.imageKey);if(!check.ok||sha(Buffer.from(await check.arrayBuffer()))!==sha(bytes))throw Error('Uploaded photo failed checksum verification');console.log(`${r.id}: uploaded and SHA-256 verified`);
}
