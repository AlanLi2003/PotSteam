// One-time, explicit import of the six approved legacy demo recipes.
// The runtime reads database responses, never the legacy HTML recipe array.
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {runInNewContext} from 'node:vm';
const root=new URL('../',import.meta.url);
const source=await readFile(new URL('reference/CNrecipe_v1.1_interactive.html',root),'utf8');
const start=source.indexOf('const ingredients=');
const end=source.indexOf('const groups=',start);
const recipes=runInNewContext(source.slice(start,end)+';recipes',{}, {timeout:1000});
const ingredientByName=new Map();
const slug=s=>s.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
const documents=recipes.map((r,index)=>({
 id:r.id,version:1,name:r.name,chineseName:r.cn,minutes:r.time,difficulty:r.level,
 vegetarian:r.veg,category:r.category,demo:true,imageKey:`recipes/${r.id}/v1.jpg`,
 bundledImage:`${index}.jpg`,allergens:r.allergens,baseServings:2,
 ingredients:r.items.map((i,n)=>{
  const ingredientId=slug(i.name);
  ingredientByName.set(i.name,{id:ingredientId,name:i.name});
  return {id:`${r.id}-v1-ingredient-${n+1}`,ingredientId,name:i.name,
   metricQuantity:i.metric,metricUnit:i.munit,usQuantity:i.us,usUnit:i.uunit};
 }),
 equipment:[{id:'cooking-pan-and-utensils',name:'Cooking pan and utensils'}],
 steps:r.steps.map((s,n)=>({id:`${r.id}-v1-step-${n+1}`,title:s[0],instruction:s[1],tip:s[2],durationSeconds:s[3]})),
}));
const seed={schemaVersion:1,source:'Legacy V1.1 demo; culinary review pending',
 sourceSHA256:createHash('sha256').update(source).digest('hex'),
 ingredients:[...ingredientByName.values()],recipes:documents};
await mkdir(new URL('backend/seeds/',root),{recursive:true});
await writeFile(new URL('backend/seeds/catalog.json',root),JSON.stringify(seed,null,2)+'\n');
console.log(`Imported ${documents.length} demo recipes, ${ingredientByName.size} stable ingredients and ${documents.reduce((n,r)=>n+r.steps.length,0)} versioned steps.`);
