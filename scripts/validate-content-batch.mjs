// Validate the English editorial release package before catalog writes.
import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
export function validateContentBatch(batch) {
 const errors=[]; const seen=new Set();
 if(batch?.language!=='en') errors.push('Current App requires English (en).');
 if(!Array.isArray(batch?.recipes)||!batch.recipes.length) return [...errors,'No recipes.'];
 const text=(v,path)=>{if(typeof v!=='string'||!v.trim()||!/[A-Za-z]/.test(v)||/\p{Script=Han}/u.test(v)) errors.push(`${path}: English text required; Chinese belongs in chineseName.`);};
 const ingredientMap=new Map();
 for(const i of batch.ingredients||[]){if(!/^[a-z0-9-]{1,100}$/.test(i.id)||ingredientMap.has(i.id))errors.push('Invalid/duplicate ingredient identity: '+i.id);text(i.name,'ingredient dictionary');ingredientMap.set(i.id,i.name);}
 if(batch.batchId==='classic-50-2026-11-02'&&batch.recipes.length!==50)errors.push('The first release must contain exactly 50 recipes.');
 for(const r of batch.recipes){
  if(!r||typeof r!=='object'){errors.push('Invalid recipe');continue;}
  const key=`${r.id}@${r.version}`;
  if(!/^[a-z0-9-]{1,100}$/.test(r.id)||!Number.isInteger(r.version)||r.version<1||seen.has(r.id)) errors.push(`${key}: invalid or duplicate identity`);
  seen.add(r.id);
  for(const f of ['name','difficulty','category'])text(r[f],`${key}.${f}`);
  if(!['Beginner','Intermediate','Advanced'].includes(r.difficulty))errors.push(`${key}: invalid difficulty`);
  if(typeof r.chineseName!=='string'||!r.chineseName.trim()||typeof r.vegetarian!=='boolean'||r.demo!==false)errors.push(`${key}: incomplete identity/category`);
  if(r.scalingMode!==undefined&&r.scalingMode!=='wholeBatch')errors.push(`${key}: invalid scaling mode`);
  for(const f of ['ingredients','equipment','steps']) if(!Array.isArray(r[f])||!r[f].length) errors.push(`${key}.${f}: required`);
  for(const f of ['ingredients','equipment','steps']){const ids=(r[f]||[]).map(x=>x.id);if(ids.some(x=>typeof x!=='string'||!x)||new Set(ids).size!==ids.length)errors.push(`${key}.${f}: invalid/duplicate item ids`);}
  for(const i of r.ingredients||[]){
   text(i.name,`${key}.ingredient.name`);
   if(ingredientMap.get(i.ingredientId)!==i.name)errors.push(`${key}: unmapped or inconsistent ingredient ${i.ingredientId}`);
   const variable=['toTaste','asNeeded'].includes(i.quantityMode);
   if(i.quantityMode!==undefined&&!variable)errors.push(`${key}: invalid quantity mode`);
   for(const q of ['metricQuantity','usQuantity'])if(!Number.isFinite(i[q])||(variable?i[q]!==0:i[q]<=0))errors.push(`${key}.${q}: invalid quantity`);
   for(const u of ['metricUnit','usUnit']){if(variable){if(i[u]!=='')errors.push(`${key}: variable quantity must omit numeric unit`);}else text(i[u],`${key}.${u}`);}
  }
  for(const e of r.equipment||[])text(e.name,`${key}.equipment.name`);
  for(const s of r.steps||[]){for(const f of ['title','instruction'])text(s[f],`${key}.step.${f}`);if(s.tip)text(s.tip,`${key}.step.tip`);if(!Number.isInteger(s.durationSeconds)||s.durationSeconds<0)errors.push(`${key}: invalid step duration`);}
  if(!Array.isArray(r.allergens))errors.push(`${key}: allergens required`);else for(const a of r.allergens)text(a,`${key}.allergen`);
  if(!Number.isInteger(r.baseServings)||r.baseServings<1||!Number.isInteger(r.minutes)||r.minutes<=0) errors.push(`${key}: servings/time required`);
  if(r.imageKey!==`recipes/${r.id}/v${r.version}.jpg`||!/^[a-zA-Z0-9-]+\.jpg$/.test(r.bundledImage))errors.push(`${key}: invalid cover path`);
  const requiredReviews = batch.acceptancePolicy === 'source-english-technical' ? ['english','rights','safety','editorial'] : ['english','rights','culinary','safety','editorial'];
  for(const f of requiredReviews){const a=r.review?.[f];if(a?.status!=='passed'||!a.reviewer||!a.evidence)errors.push(`${key}: ${f} review evidence required`);}
 }
 return errors;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 const batch=JSON.parse(await readFile(process.argv[2],'utf8'));const errors=validateContentBatch(batch);
 console.log(JSON.stringify({passed:!errors.length,recipes:batch.recipes?.length,errors},null,2));if(errors.length)process.exitCode=1;
}
