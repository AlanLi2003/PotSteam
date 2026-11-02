"""Extend the existing thin-line icon vocabulary for the released ingredients."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1];out=root/'docs/content/first-50/assets/icons';out.mkdir(parents=True,exist_ok=True)
paths={
'water':'<path d="M12 3C10 7 5 12 5 16a7 7 0 0 0 14 0c0-4-5-9-7-13Z"/><path d="M8 16c0 2 1 3 3 3"/>',
'sugar':'<path d="m4 8 6-3 6 3v7l-6 3-6-3Zm0 0 6 3 6-3M10 11v7m6-8 4 2v7l-6 3-4-2m6-5 4-3M14 22v-7"/>',
'wine':'<path d="M10 3h4v6l4 4v8H6v-8l4-4Zm0 3h4M7 15h10M9 18h6"/>',
'potato':'<path d="M5 7c4-5 11-4 14 1 4 6 0 12-6 13S1 15 5 7Z"/><path d="m7 9 1 1m6-4 1 1m2 6-1 1m-7 3 1-1"/>',
'cabbage':'<path d="M12 3C4 3 1 11 5 18c3 5 13 4 15-3 2-6-2-12-8-12Z"/><path d="M12 21c-5-5-8-9-6-13m6 13c5-5 8-9 6-13M12 21V8m0 6-4-3m4 7 5-5"/>',
'broccoli':'<path d="m9 21 1-7H6a4 4 0 0 1-1-8 4 4 0 0 1 7-2 4 4 0 0 1 7 3 4 4 0 0 1-1 8h-4l1 6Zm1-7 2-4 2 4M9 21h6"/>',
'carrot':'<path d="M5 20c0-7 3-15 7-13s6 7-7 13Zm7-13 1-4m1 5 5-4m-4 6 5-1M8 12l3 2m-5 2 2 1"/>',
'eggplant':'<path d="M16 6c-4-2-9 0-10 5-1 3-3 5-3 6 0 3 5 4 9 2 6-2 9-8 4-13Z"/><path d="m16 6 1-3m-1 3-4 1 3 2 3-1M7 14c0-3 2-4 4-5"/>',
'bell-pepper':'<path d="M12 7c-7-4-11 4-7 12 2 4 4 1 7 2 3-1 5 2 7-2 4-8 0-16-7-12Zm0 0c-1-2 0-4 3-4M9 10c-2 3-2 5-1 8m7-8c2 3 2 5 1 8"/>',
'mushroom':'<path d="M3 12c0-11 18-11 18 0Zm7 0-1 9h6l-1-9"/><circle cx="8" cy="8" r="1"/><circle cx="15" cy="6" r="1"/>',
'ginger':'<path d="m8 20-3-1 1-5-3-2 1-3 4 1V5l3-1 2 5 5-2 2 3-5 4 4 3-2 3-5-2Zm0-10 3 3m2-4-1 5m3 0-3 4"/>',
'bamboo':'<path d="m5 21 3-18h5l-2 18Zm2-12h5m-6 6h5m2 6 3-13h5l-3 13Zm2-7h5"/>',
'cucumber':'<path d="M5 20c-4-4 8-20 13-16s-9 20-13 16Z"/><path d="m7 16 1 1m3-6 1 1m2-5 1 1M6 19 17 5"/>',
'herbs':'<path d="M12 22V6m0 7C3 15 2 7 4 5c5-1 8 3 8 8Zm0 5c8 2 11-5 9-8-5-1-9 3-9 8Zm0-10c-4-5-2-7 0-7s4 3 0 7Z"/>',
'beef':'<path d="M5 5c3-3 12 0 15 4s-2 12-7 12H6C1 18 1 8 5 5Z"/><ellipse cx="14" cy="11" rx="3" ry="4"/><path d="M6 8c-2 3-1 7 2 9"/>',
'fish':'<path d="M5 12c5-9 11-8 16 0-5 8-11 9-16 0Zm0 0-4-5v10Zm7-6c-2 3-2 9 0 12"/><circle cx="17" cy="11" r=".6"/>',
'shrimp':'<path d="M17 5C7-1 1 9 5 16c3 6 11 5 14 1l-4-3c-3 4-8 0-6-3 1-2 4-3 8-1Z"/><path d="m17 5 5-3m-5 5 5-1M6 6l4 3m-6 2 4 1m-3 5 3-2m1 5 2-3m4-3 4-1 2 4-2 1"/>',
'oyster':'<path d="M4 17C-1 7 10 2 13 4c4-2 12 7 7 14-5 5-12 5-16-1Z"/><path d="M7 16c-2-6 4-10 7-7s4 8-2 9Z"/>',
'stock':'<path d="M3 11h18c-1 7-4 10-9 10s-8-3-9-10ZM6 15h12M8 8c-3-3 3-3 0-6m8 6c-3-3 3-3 0-6"/>',
'powder':'<path d="M7 3h10l-1 5 4 13H4L8 8Zm1 5h8M7 17h10M9 13h6"/>',
'star-anise':'<path d="m12 2 2 6 5-3-2 6 5 2-6 2 2 6-6-4-5 5 1-7-6-2 6-3-3-5 6 3Z"/><circle cx="12" cy="12" r="2"/>',
'beans':'<ellipse cx="8" cy="10" rx="4" ry="6" transform="rotate(25 8 10)"/><path d="M9 6c-4 1 1 6-3 8"/><ellipse cx="17" cy="16" rx="4" ry="5"/><path d="M17 13c-3 1 2 4 0 6"/>',
'lotus-root':'<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="1.4"/><ellipse cx="12" cy="6.5" rx="1.3" ry="2"/><ellipse cx="12" cy="17.5" rx="1.3" ry="2"/><ellipse cx="6.5" cy="10" rx="1.5" ry="2"/><ellipse cx="17.5" cy="10" rx="1.5" ry="2"/><circle cx="7.5" cy="16" r="1.3"/><circle cx="16.5" cy="16" r="1.3"/>',
'berries':'<path d="M12 3v7m-1-3L7 5m6 2 4-3"/><ellipse cx="8" cy="14" rx="3" ry="6" transform="rotate(20 8 14)"/><ellipse cx="17" cy="14" rx="3" ry="6" transform="rotate(-20 17 14)"/>',
'cinnamon':'<path d="m4 17 12-12c4-2 7 3 4 6L8 22c-4 1-6-3-3-5 2-2 5 1 3 3M16 5c-2 1-1 5 2 4m-9 7L19 6"/>',
'fruit':'<circle cx="12" cy="14" r="8"/><path d="M12 6V2m0 4c3-5 6-4 7-3-1 3-4 4-7 3M7 12c0-2 2-3 3-3"/>',
'onion':'<path d="M10 3h4l-1 5c10 6 8 13-1 13S1 14 11 8Zm2 5c-5 6-4 10 0 13m0-13c5 6 4 10 0 13M8 23l4-2 4 2"/>',
'wrappers':'<ellipse cx="12" cy="8" rx="9" ry="4"/><path d="M3 8v9c0 5 18 5 18 0V8M3 12c2 5 16 5 18 0M3 16c2 5 16 5 18 0"/>',
'peas':'<path d="M3 19C2 8 12 1 21 4c0 9-8 18-18 15Z"/><circle cx="8" cy="15" r="2"/><circle cx="12" cy="11" r="2"/><circle cx="16" cy="7" r="2"/>',
'seaweed':'<path d="M8 22c-5-5 2-6-1-10S5 5 8 2m5 20c-4-5 3-7 0-11s-2-5 0-8m5 19c-4-4 2-7 0-10s-1-5 1-8M4 22h17"/>',
'chestnut':'<path d="M4 15c0-4 3-6 8-12 5 6 8 8 8 12 0 9-16 9-16 0ZM4 16c5-2 11-2 16 0M12 6v5"/>'
}
for name,body in paths.items():
 (out/(name+'.svg')).write_text(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">{body}</svg>\n')
def icon(name):
 s=name.lower()
 if s=='chili bean paste':return 'bean-paste'
 checks=[(['shaoxing'],'wine'),(['soaking liquid','stock'],'stock'),(['water chestnut'],'chestnut'),(['sugar'],'sugar'),(['starch','flour','baking soda','breadcrumbs'],'powder'),(['whole sea bass','fish','carp'],'fish'),(['shrimp'],'shrimp'),(['oyster,','oysters'],'oyster'),(['sauce','vinegar','ketchup'],'soy-sauce'),(['salt'],'salt'),(['cooking oil','sesame oil'],'oil'),(['water'],'water'),(['chive','scallion','leek'],'scallions'),(['tomato'],'tomato'),(['eggplant'],'eggplant'),(['egg'],'egg'),(['potato'],'potato'),(['napa cabbage','cabbage'],'cabbage'),(['bok choy','mustard greens'],'bok-choy'),(['broccoli'],'broccoli'),(['carrot'],'carrot'),(['bell pepper'],'bell-pepper'),(['peppercorn','white pepper','black pepper','five-spice','sand ginger','cumin','sesame seeds'],'pepper'),(['chili','chilies','pepper flakes'],'chilies'),(['garlic'],'garlic'),(['ginger'],'ginger'),(['mushroom','shiitake'],'mushroom'),(['bamboo'],'bamboo'),(['cucumber','winter melon'],'cucumber'),(['cilantro','basil','perilla','bean sprout'],'herbs'),(['beef'],'beef'),(['chicken','duck'],'chicken'),(['pork','ham'],'pork'),(['star anise'],'star-anise'),(['tofu'],'tofu'),(['beans'],'beans'),(['lotus'],'lotus-root'),(['goji'],'berries'),(['cassia'],'cinnamon'),(['lemons','plums'],'fruit'),(['shallot'],'onion'),(['dumpling'],'wrappers'),(['peas'],'peas'),(['seaweed'],'seaweed'),(['rice'],'rice'),(['noodles'],'noodles'),(['peanut'],'peanuts')]
 for words,asset in checks:
  if any(w in s for w in words):return asset
 raise ValueError(name)
seed=json.loads((root/'backend/seeds/catalog.json').read_text());mapping={}
for item in seed['ingredients']:
 asset=icon(item['name']);mapping[item['id']]=asset;key=' '.join(item['name'].lower().replace('-',' ').split());mapping['name:'+key]=asset
(root/'ios/CNrecipe/Content/ingredient-icons.json').write_text(json.dumps(mapping,indent=2)+'\n')
(root/'docs/content/first-50/ingredient-icon-rights.json').write_text(json.dumps({'newAssets':sorted(paths),'basis':'Original geometric SVG linework created for the new ingredients; existing supplied icons reused where semantically applicable','mapping':'ios/CNrecipe/Content/ingredient-icons.json'},indent=2)+'\n')
print('Created',len(paths),'original supplementary icons and mapped',len(seed['ingredients']),'ingredients.')
