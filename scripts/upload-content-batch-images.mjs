import {readFile,mkdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {spawn} from 'node:child_process';
const batch=JSON.parse(await readFile(process.argv[2]||'docs/content/first-50/batches/classic-50-en.json','utf8'));
const project='mlrerdrnwuudjsnjodkp',root=`https://${project}.supabase.co/storage/v1/object/public/recipe-images/`,sha=b=>createHash('sha256').update(b).digest('hex');
const out=process.argv[3]||'artifacts/classic-50-release';await mkdir(out,{recursive:true});const results=[];
async function upload(r){
 const path='ios/CNrecipe/Web/assets/'+r.bundledImage,bytes=await readFile(path),hash=sha(bytes);let response=await fetch(root+r.imageKey);
 if(response.ok){if(sha(Buffer.from(await response.arrayBuffer()))!==hash)throw Error('Immutable image conflict: '+r.id);return {id:r.id,imageKey:r.imageKey,sha256:hash,result:'already verified'};}
 if(![400,404].includes(response.status))throw Error(`Image preflight failed: ${response.status}`);
 await new Promise((resolve,reject)=>{const child=spawn('npx',['supabase','storage','cp',path,'ss:///recipe-images/'+r.imageKey,'--project-ref',project,'--linked','--experimental','--content-type','image/jpeg','--cache-control','public,max-age=31536000,immutable'],{stdio:['ignore','pipe','pipe']});let output='';child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);child.on('error',reject);child.on('close',code=>code===0?resolve():reject(Error(`Image upload failed for ${r.id}: ${output.slice(-600)}`)));});
 response=await fetch(root+r.imageKey);if(!response.ok||sha(Buffer.from(await response.arrayBuffer()))!==hash)throw Error('Image verification failed: '+r.id);
 return {id:r.id,imageKey:r.imageKey,sha256:hash,result:'uploaded and verified'};
}
let index=0;await Promise.all(Array.from({length:3},async()=>{while(index<batch.recipes.length){const r=batch.recipes[index++];const result=await upload(r);results.push(result);console.log(result.id+': '+result.result);await writeFile(out+'/image-upload.json',JSON.stringify(results,null,2)+'\n');}}));
if(results.length!==50)throw Error('Incomplete cover upload');
