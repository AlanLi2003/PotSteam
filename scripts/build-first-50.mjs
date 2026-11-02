import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root=new URL('../',import.meta.url),base=new URL('docs/content/first-50/',root);
const read=async path=>JSON.parse(await readFile(new URL(path,base),'utf8'));
const facts=await read('editorial/recipes-facts.json'),methods=await read('editorial/english-methods.json'),titles=await read('editorial/english-titles.json'),selection=await read('selection.json');
const original=await read('sources/english-structured-sources.json'),targeted=await read('sources/targeted-structured-sources.json');
const by=(rows,n)=>rows.find(x=>x.number===n);
const sources=[];const reviews=[];
const legacy={1:'tomato',21:'mapo',22:'kung',47:'noodles'};
const slug=s=>s.toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'');
const alias={
 'Cooking oil':['cooking-oil','Cooking oil'],'Light soy sauce':['light-soy-sauce','Light soy sauce'],
 'Eggs, beaten':['eggs','Eggs'],'Whole chicken':['whole-chicken','Whole chicken'],
 'Scallions':['scallions','Scallions'],'Tofu':['tofu','Tofu'],'Wheat noodles':['noodles','Noodles'],
 'Noodles':['noodles','Noodles'],'Wood ear mushrooms, rehydrated':['rehydrated-wood-ear-mushrooms','Wood ear mushrooms (rehydrated)'],
 'Coarse rock salt, baking bed only':['salt-bed','Coarse rock salt (baking bed, not for eating)']
};
const existing=JSON.parse(await readFile(new URL('backend/seeds/catalog.json',root),'utf8'));
const ingredientNames=new Map(existing.ingredients.map(i=>[i.id,i.name]));
const sourceOverrides={
17:{url:by(selection.recipes.map(x=>({number:x.number,...x})),17).references[0].url,path:by(selection.recipes.map(x=>({number:x.number,...x})),17).references[0].path},
20:{url:by(selection.recipes.map(x=>({number:x.number,...x})),20).references[0].url,path:by(selection.recipes.map(x=>({number:x.number,...x})),20).references[0].path},
26:{url:'https://www.chinarecipes.com/sichuan-boiled-pork-shui-zhu-rou-pian-recipe-34060/',path:by(targeted,26).sources[0].path},
27:{url:by(original,27).sources[0].url,path:by(original,27).sources[0].path},
32:{url:by(targeted,32).sources[0].url,path:by(targeted,32).sources[0].path},
33:{url:'http://chuzhuge.com/pcpinfo/11377',path:'docs/content/first-50/sources/targeted-discovery.json'},
34:{url:'https://thewoksoflife.com/lions-head-meatballs/',path:'docs/content/first-50/sources/braised-lions-head-discovery.json'},
37:{url:by(selection.recipes.map(x=>({number:x.number,...x})),37).references[0].url,path:by(selection.recipes.map(x=>({number:x.number,...x})),37).references[0].path},
38:{url:'https://m.xiachufang.com/recipe/100404095/',path:'docs/content/first-50/sources/prepared-fish-discovery.json'},
41:{url:by(original,41).sources[0].url,path:by(original,41).sources[0].path},
44:{url:'https://www.renrendoc.com/paper/407379443.html',path:'docs/content/first-50/sources/targeted-discovery.json'},
45:{url:by(original,45).sources[0].url,path:by(original,45).sources[0].path}
};
const specificSource={11:by(original,11).sources[1]};
const targetUse=new Set([1,5,10,16,21,23,47,50]);const secondUse=new Set([2,4,7,11,12,13,14,15,19,40,49]);
const veg=new Set([2,3,4,5,6,7,8,9,10,11,47,48,50,1]);
const beginner=new Set([1,2,3,4,5,7,10,11,19,20,28,36,39,47,48,49]);
const regions={21:'Sichuan',22:'Sichuan',23:'Sichuan',24:'Sichuan',25:'Sichuan',26:'Sichuan',27:'Hunan',28:'Hunan',29:'Cantonese',30:'Hakka',31:'Hakka',32:'Fujian',33:'Huaiyang',34:'Huaiyang',35:'Zhejiang',36:'Shanghai',37:'Shandong',38:'Anhui',39:'Hubei',40:'Northeastern',41:'Yunnan',42:'Xinjiang',43:'Chinese regional',44:'Guangxi'};
const whole=new Set([18,27,29,31,35,38]);
const categories=n=>n>=45?'Rice & Noodles':regions[n]||([19,20].includes(n)?'Soups':'Home-style');
const equipment=n=>[18,27,30,13].includes(n)?['Steamer','Heatproof plate','Food thermometer']:n===31?['Oven','Oven-safe casserole','Baking parchment','Kitchen string','Food thermometer']:n===41?['Yunnan steam pot with matching lower pot','Heatproof mitts','Food thermometer']:n===50?['Mixing bowl','Rolling pin','Lidded skillet']:n===45?['Mixing bowl','Large saucepan','Slotted spoon','Food thermometer']:[9,34,37,40].includes(n)?['Deep heavy pan','Frying thermometer','Slotted spoon','Food thermometer']:[14,16,17,19,24,29,33,35,36,38,39,42,43,44,49].includes(n)?['Lidded heavy pot','Knife and cutting board','Food thermometer']:['Wok or skillet','Knife and cutting board','Spatula'];
function allergen(items){const a=new Set();for(const i of items){const s=i.name.toLowerCase();if(/egg/.test(s)&&!/eggplant/.test(s))a.add('Eggs');if(/shrimp/.test(s))a.add('Crustaceans');if(/oyster/.test(s)&&!/vegetarian/.test(s))a.add('Molluscs');if(/fish|carp|bass/.test(s))a.add('Fish');if(/soy|tofu|bean paste|bean sauce|fermented black bean/.test(s))a.add('Soy');if(/soy sauce|noodles|wheat|breadcrumbs|flour|dumpling wrapper|bean paste|bean sauce/.test(s)&&!/corn|potato|sweet potato/.test(s))a.add('Wheat');if(/sesame/.test(s))a.add('Sesame');if(/peanut/.test(s))a.add('Peanuts');}return [...a].sort();}
const recipes=[];
for(const f of facts){
 const n=f.n,id=legacy[n]||'classic-'+String(n).padStart(2,'0')+'-'+slug(titles[n-1]).slice(0,65),version=legacy[n]?2:1;
 const src=specificSource[n]||sourceOverrides[n]||by(targetUse.has(n)?targeted:original,n).sources[secondUse.has(n)?1:0];
 if(!src)throw Error('No source '+n);
 const bytes=await readFile(new URL(src.path,root));
 sources.push({number:n,recipeId:id,url:src.url,archive:src.path,sha256:createHash('sha256').update(bytes).digest('hex'),use:'Ingredient and process facts only; no third-party photo or expressive prose published.'});
 const ingredients=f.items.split(';').map((entry,index)=>{
  const [label,amount,unit]=entry.split('|');let [ingredientId,name]=alias[label]||[slug(label),label];if(ingredientNames.has(ingredientId))name=ingredientNames.get(ingredientId);else ingredientNames.set(ingredientId,name);
  let q=Number(amount),metric=q,mu=unit,us=q,uu=unit;
  if(unit==='lb'){metric=q*453.59237;mu='g';us=q*16;uu='oz';}
  if(unit==='oz'){metric=q*28.349523125;mu='g';}
  if(unit==='g'){us=q/28.349523125;uu='oz';}
  if(unit==='mL'){us=q/29.5735295625;uu='fl oz';}
  if(unit==='inch'){metric=q*2.54;mu='cm';}
  if(unit==='cm'){us=q/2.54;uu='inch';}
  const volume={tsp:4.92892159375,tbsp:14.78676478125,cup:236.5882365,quart:946.352946};
  if(volume[unit]){let ratio=volume[unit];if(src.url.includes('gourmettraveller.com.au'))ratio=unit==='tbsp'?20:unit==='tsp'?5:unit==='cup'?250:ratio;else if(/redhousespice|bbc.co.uk|lkk.com|dachu.co|renrendoc|chinarecipes|chuzhuge|xiachufang|githubusercontent/.test(src.url))ratio=unit==='tbsp'?15:unit==='tsp'?5:unit==='cup'?250:ratio;metric=q*ratio;mu='mL';us=metric/volume[unit];}
  const item={id:`${id}-v${version}-ingredient-${index+1}`,ingredientId,name,metricQuantity:metric,metricUnit:mu,usQuantity:us,usUnit:uu};
  if(q===0){item.quantityMode=unit==='to taste'?'toTaste':'asNeeded';item.metricUnit='';item.usUnit='';}
  if(n===31&&label.startsWith('Coarse'))item.nonEdible=true;
  return item;
 });
 const steps=methods[n].map((entry,index)=>{const at=entry.indexOf('|');return {id:`${id}-v${version}-step-${index+1}`,title:entry.slice(0,at),instruction:entry.slice(at+1),tip:'',durationSeconds:0};});
 const tips=[];
 if(whole.has(n))tips.push('This is a whole-item recipe. Quantities stay at one full batch for fewer diners; larger groups use additional whole batches. Cook each batch with adequate equipment capacity.');
 if(n===31)tips.push('The coarse salt forms the baking bed and is not eaten. Use enough to enclose the parcel for your casserole; do not scale it down by plate count.');
 if([9,34,37,40].includes(n))tips.push('Keep frying oil below halfway up the pan, dry ingredients thoroughly and fry in small batches. Use a refined oil rated for the stated frying temperature; never heat oil until smoking. The oil quantity is for cooking, not an amount to eat.');
 if(n===33)tips.push('The salt measure is an upper seasoning amount; use less with salted stock or ham.');
 if(ingredients.some(i=>/egg/i.test(i.name)&&!/eggplant/i.test(i.name)))tips.push('For fractional egg quantities, beat the egg first and measure the required portion.');
 const protein=ingredients.some(i=>/pork|beef|chicken|duck|fish|carp|bass|shrimp|oyster|egg/i.test(i.name)&&!/eggplant|vegetarian/.test(i.name));
 if(protein&&!steps.some(s=>/thermometer|°C/.test(s.instruction))){tips.push('Use a food thermometer: poultry and reheated leftovers 74°C / 165°F; ground meat and egg dishes 72°C / 160°F; fish 63°C / 145°F. Whole cuts of pork or beef need 63°C / 145°F plus a 3-minute rest.');}
 tips.push('Check packaged sauces for allergens and follow label directions.');steps.at(-1).tip=tips.join(' ');
 const evidence='docs/content/first-50/editorial/review-notes.md#recipe-'+n;
 const review=Object.fromEntries(['english','rights','safety','editorial'].map(kind=>[kind,{status:'passed',reviewer:'Codex source and editorial review',evidence}]));
 const recipe={id,version,name:titles[n-1],chineseName:selection.recipes[n-1].chineseName,minutes:f.minutes,difficulty:beginner.has(n)?'Beginner':'Intermediate',vegetarian:veg.has(n),category:categories(n),demo:false,imageKey:`recipes/${id}/v${version}.jpg`,bundledImage:`classic-${String(n).padStart(2,'0')}.jpg`,allergens:allergen(ingredients),baseServings:f.servings,ingredients,equipment:equipment(n).map(name=>({id:slug(name),name})),steps};
 if(whole.has(n))recipe.scalingMode='wholeBatch';
 recipes.push({...recipe,review});
 reviews.push(`## Recipe ${n}\n\nSource: ${src.url}\n\n- English wording composed for CNrecipe from ingredient/process facts; creative headnotes, photos and source sentences excluded.\n- Quantities checked against archived source; where ranges exist use a stated endpoint. Serving allocations without explicit source yields and extra preparation/soaking time are editorial planning estimates, not measured cooking results.\n- Deliberate adaptations: omit optional garnishes/side dishes; preserve source seasoning and vessel-fill quantities as To taste / As needed instead of invented grams. Steaming water is vessel-dependent. Replace raw-poultry washing, color-only doneness and smoking-oil directions with safe handling and thermometer checks.\n- Cover: original CNrecipe geometric/type artwork in image-rights.json; no external photographs.\n- No actual cooking or independent human review claimed, as authorized by user.\n`);
}
const ids=new Set(recipes.flatMap(r=>r.ingredients.map(i=>i.ingredientId)));
const ingredients=[...ids].map(id=>({id,name:ingredientNames.get(id)}));
const batch={schemaVersion:1,language:'en',acceptancePolicy:'source-english-technical',batchId:'classic-50-2026-11-02',ingredients,recipes};
await mkdir(new URL('batches/',base),{recursive:true});
await writeFile(new URL('batches/classic-50-en.json',base),JSON.stringify(batch,null,2)+'\n');
await writeFile(new URL('editorial/source-register.json',base),JSON.stringify(sources,null,2)+'\n');
await writeFile(new URL('editorial/review-notes.md',base),'# Editorial source review\n\n2026-11-02. Agent-performed source, language, rights-of-published-assets and safety checks; not independent human approval or cooking validation.\n\nRights basis: factual ingredient lists and methods are independently expressed. U.S. Copyright Office: https://www.copyright.gov/help/faq/faq-protect.html . No third-party expressive prose, photos or illustrations are published. Research archives are internal only.\n\nSafety basis: https://www.fsis.usda.gov/food-safety/safe-food-handling-and-preparation/food-safety-basics/safe-temperature-chart . Higher rounded Celsius values are used when necessary.\n\nUnit policy: mass conversion uses 28.349523125 g/oz. US liquid measures use their exact volume definitions. Metric spoon/cup conventions for non-US sources are recorded in build-first-50.mjs; no food density conversions are inferred.\n\n'+reviews.join('\n'));
console.log(`Built ${recipes.length} English recipes and ${ingredients.length} canonical ingredients.`);
