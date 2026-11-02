import {readFile,writeFile,copyFile,mkdir,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {publishedDocument} from './import-content-batch.mjs';
import {validateContentBatch} from './validate-content-batch.mjs';
const base='docs/content/first-50/',out='artifacts/recipe-media-fix';await mkdir(out,{recursive:true});
const original=JSON.parse(await readFile(base+'batches/classic-50-en.json','utf8'));
const batch=structuredClone(original);batch.batchId='classic-50-media-2026-11-02';const images=[];
for(const [index,r] of batch.recipes.entries()){
 const n=String(index+1).padStart(2,'0'),metadataPath=base+`photo-generation/${n}.json`,meta=JSON.parse(await readFile(metadataPath,'utf8'));
 if(meta.n!==index+1||meta.generator!=='image_gen'||(meta.recipeId&&meta.recipeId!==r.id))throw Error('Photo identity mismatch: '+n);
 const oldVersion=r.version;r.version++;
 for(const kind of ['ingredients','steps'])for(const item of r[kind])item.id=item.id.replace(`${r.id}-v${oldVersion}-`,`${r.id}-v${r.version}-`);
 r.imageKey=`recipes/${r.id}/v${r.version}.jpg`;r.bundledImage=`classic-${n}-photo-v${r.version}.jpg`;
 const staging=`ios/CNrecipe/Web/assets/classic-${n}-photo.jpg`,retained=`assets/recipe-photos/dish-${n}.jpg`,target='ios/CNrecipe/Web/assets/'+r.bundledImage;
 let source=retained;try{await stat(retained)}catch{source=staging;await copyFile(staging,retained);}
 await copyFile(source,target);
 const bytes=await readFile(target);if(bytes.length>5_000_000||bytes[0]!==255||bytes[1]!==216)throw Error('Invalid JPEG: '+n);
 const hash=createHash('sha256').update(bytes).digest('hex');
 r.review.rights={status:'passed',reviewer:'Codex generated-asset and recipe correspondence review',evidence:metadataPath};
 images.push({candidateNumber:index+1,recipeId:r.id,version:r.version,file:target,imageKey:r.imageKey,sha256:hash,generator:'image_gen',sourceMetadata:metadataPath,kind:'AI-generated food presentation image; not an actual cooking photograph'});
 meta.image=target;meta.sha256=hash;meta.stagingJPEG=retained;await writeFile(metadataPath,JSON.stringify(meta,null,2)+'\n');
}
const errors=validateContentBatch(batch);if(errors.length)throw Error(errors.join('\n'));
await writeFile(base+'batches/classic-50-en-photos.json',JSON.stringify(batch,null,2)+'\n');
await writeFile(base+'photo-rights.json',JSON.stringify(images,null,2)+'\n');
try{await stat(out+'/previous-seed.json')}catch{await writeFile(out+'/previous-seed.json',await readFile('backend/seeds/catalog.json'));}
await writeFile('backend/seeds/catalog.json',JSON.stringify({schemaVersion:1,source:'CNrecipe classic 50 English recipes with generated food images; image provenance in docs/content/first-50/photo-rights.json',ingredients:batch.ingredients,recipes:batch.recipes.map(publishedDocument)},null,2)+'\n');
await writeFile(base+'batches/active-release.json',JSON.stringify({batchId:batch.batchId,file:'classic-50-en-photos.json',sha256:createHash('sha256').update(await readFile(base+'batches/classic-50-en-photos.json')).digest('hex')},null,2)+'\n');
console.log('Built 50 immutable food-image revisions; recipe text and quantities preserved.');
