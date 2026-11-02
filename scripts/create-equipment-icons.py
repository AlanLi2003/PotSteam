"""Complete the existing SVG vocabulary with exact equipment/name mappings."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
out=root/'docs/content/first-50/assets/icons';out.mkdir(parents=True,exist_ok=True)
paths={
'equipment-wok':'<path d="M3 9h16c-1 7-4 10-8 10S4 16 3 9Zm16 1 4-3M8 21h6M8 5c-2-2 2-2 0-4m6 4c-2-2 2-2 0-4"/>',
'equipment-pot':'<path d="M5 8h14v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2ZM3 7h18M10 4h4M5 11H2v4h3m14-4h3v4h-3M9 12v5"/>',
'equipment-skillet':'<path d="M3 10h14v3c0 4-14 4-14 0Zm14 1 6-3M6 7h8M9 4h3"/>',
'equipment-steamer':'<path d="M4 8h16v12H4Zm-1 0 4-4h10l4 4M10 2h4M4 14h16M7 10v2m3-2v2m4-2v2m3-2v2M7 16v2m3-2v2m4-2v2m3-2v2"/>',
'equipment-steam-pot':'<path d="M3 12h18v7c0 4-18 4-18 0ZM5 12V7c3-4 11-4 14 0v5M6 7h12M10 12V9h4v3M10 3h4M3 16h18M2 9h3m14 0h3"/>',
'equipment-plate':'<ellipse cx="12" cy="15" rx="10" ry="5"/><ellipse cx="12" cy="15" rx="6" ry="2.5"/><path d="M8 8c-2-3 2-3 0-6m8 6c-2-3 2-3 0-6"/>',
'equipment-thermometer':'<path d="M9 14V5a3 3 0 0 1 6 0v9a5 5 0 1 1-6 0Z"/><path d="M12 7v10m4-9h3m-3 4h2"/><circle cx="12" cy="18" r="1.4"/>',
'equipment-probe':'<path d="M5 3h12v8H5Zm6 8v10m-3-1h6M8 6h6m-6 2h3"/>',
'equipment-board':'<path d="M5 6h14v16H5Zm4 0V3h6v3M8 10h8M8 18h8M10 10v7m4-7v7"/><path d="m16 8-5 7 2 1 5-7"/>',
'equipment-oven':'<rect x="3" y="3" width="18" height="19" rx="2"/><path d="M3 8h18M7 11h10v7H7Zm1 1h8"/><circle cx="7" cy="5.5" r=".6"/><circle cx="12" cy="5.5" r=".6"/><circle cx="17" cy="5.5" r=".6"/>',
'equipment-mitt':'<path d="M8 21H5v-8L3 9c-1-3 3-4 4-1l1 2V4c0-3 7-3 7 0v6c4 0 5 3 4 6l-2 5Zm-3-3h13M11 5v7"/>',
'equipment-parchment':'<path d="M5 5c0-4 6-4 6 0v14c0 3-6 3-6 0Zm6-2h9v16h-9M5 5c0 3 6 3 6 0M15 6h2m-2 4h2m-2 4h2"/>',
'equipment-string':'<path d="M8 5h8v14H8Zm-2-2h12M6 21h12M8 7l8 4m-8 0 8 4m-8 0 8 3m0-1c6 0 6 5 2 5"/>',
'equipment-bowl':'<path d="M2 10h20c-2 8-5 11-10 11S4 18 2 10Zm3 4h14M6 7h12m-6-1 7-4"/>',
'equipment-rolling-pin':'<path d="m5 5 14 14M3 3l3 3m12 12 3 3M4 8l4-4 12 12-4 4Z"/>',
'equipment-slotted-spoon':'<ellipse cx="9" cy="8" rx="5" ry="6" transform="rotate(-30 9 8)"/><path d="m12 13 8 9M6 6l2-1m0 4 2-1m0 4 2-1"/>',
'equipment-spatula':'<path d="m4 3 9-1 1 10-8 1Zm6 10 3 9M7 5l1 5m2-5 1 4"/>',
'wood-ear':'<path d="M12 21c-6 0-8-2-6-5-5-2-4-7 0-7-1-5 4-8 7-4 4-4 8 1 5 5 5 3 2 7-2 7 1 4-2 5-4 4Z"/><path d="M11 19c-4-2 1-4-1-7s1-5 3-4m0 12c-1-4 4-4 2-8"/>',
'duck':'<path d="M3 12h12l3-7c2-4 6-1 4 2l-3 3v5c-1 8-15 8-16-3Zm12-4 4-1M6 15c3 3 6 2 8 0M8 22v-2m7 2v-2"/>'
}
for name,body in paths.items():
 (out/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">{body}</svg>\n')
seed=json.loads((root/'backend/seeds/catalog.json').read_text());p=root/'ios/CNrecipe/Content/ingredient-icons.json';mapping=json.loads(p.read_text())
assets={'baking-parchment':'equipment-parchment','deep-heavy-pan':'equipment-pot','food-thermometer':'equipment-thermometer','frying-thermometer':'equipment-probe','heatproof-mitts':'equipment-mitt','heatproof-plate':'equipment-plate','kitchen-string':'equipment-string','knife-and-cutting-board':'equipment-board','large-saucepan':'equipment-pot','lidded-heavy-pot':'equipment-pot','lidded-skillet':'equipment-skillet','mixing-bowl':'equipment-bowl','oven':'equipment-oven','oven-safe-casserole':'equipment-pot','rolling-pin':'equipment-rolling-pin','slotted-spoon':'equipment-slotted-spoon','spatula':'equipment-spatula','steamer':'equipment-steamer','wok-or-skillet':'equipment-wok','yunnan-steam-pot-with-matching-lower-pot':'equipment-steam-pot'}
for recipe in seed['recipes']:
 for e in recipe['equipment']:
  asset=assets[e['id']];mapping['equipment:'+e['id']]=asset;key=' '.join(e['name'].lower().replace('-',' ').split());mapping['name:'+key]=asset
for item in seed['ingredients']:
 if 'wood ear' in item['name'].lower():
  mapping[item['id']]='wood-ear';mapping['name:'+' '.join(item['name'].lower().replace('-',' ').split())]='wood-ear'
 if item['name']=='Duck':mapping[item['id']]='duck';mapping['name:duck']='duck'
aliases={
'potato':['potato','potatoes','土豆','马铃薯'],
'cabbage':['cabbage','包菜','卷心菜','大白菜','白菜'],
'broccoli':['broccoli','西兰花'],
'carrot':['carrot','carrots','胡萝卜'],
'eggplant':['eggplant','aubergine','茄子'],
'mushroom':['mushroom','mushrooms','shiitake','香菇','蘑菇'],
'wood-ear':['wood ear','wood ears','木耳','黑木耳'],
'ginger':['ginger','生姜','姜'],
'bell-pepper':['bell pepper','bell peppers','青椒','甜椒'],
'cucumber':['cucumber','cucumbers','黄瓜'],
'herbs':['cilantro','coriander','香菜','紫苏'],
'beef':['beef','beef brisket','牛肉','牛腩'],
'fish':['fish','sea bass','鲈鱼','鱼','鳜鱼','草鱼'],
'shrimp':['shrimp','prawn','prawns','虾','虾仁'],
'oyster':['oyster','oysters','海蛎','牡蛎'],
'duck':['duck','鸭','鸭肉'],
'lotus-root':['lotus root','莲藕'],
'sugar':['sugar','white sugar','糖','白糖','冰糖'],
'water':['water','水','清水'],
'wine':['shaoxing wine','cooking wine','料酒','黄酒'],
'powder':['flour','cornstarch','面粉','淀粉'],
'equipment-wok':['wok','炒锅'],
'equipment-pot':['saucepan','pot','汤锅','砂锅','炖锅'],
'equipment-steamer':['蒸锅','蒸笼'],
'equipment-oven':['烤箱'],
'equipment-board':['cutting board','菜刀和砧板','砧板'],
'equipment-rolling-pin':['擀面杖'],
'equipment-thermometer':['food thermometer','食物温度计'],
'equipment-bowl':['mixing bowl','搅拌碗']
}
for asset,names in aliases.items():
 for name in names:
  key='name:'+' '.join(name.lower().replace('-',' ').split())
  if key not in mapping:mapping[key]=asset
p.write_text(json.dumps(mapping,ensure_ascii=False,indent=2)+'\n')
(root/'docs/content/first-50/equipment-icon-rights.json').write_text(json.dumps({'assets':sorted(paths),'equipmentCoverage':20,'ingredientCoverage':len(seed['ingredients']),'basis':'Original geometric SVG linework matching the existing stroke style; existing appropriate supplied icons retained','mapping':'ios/CNrecipe/Content/ingredient-icons.json'},indent=2)+'\n')
print('Mapped all 20 equipment types and',len(seed['ingredients']),'ingredients; added exact aliases and dedicated wood-ear/duck icons.')
