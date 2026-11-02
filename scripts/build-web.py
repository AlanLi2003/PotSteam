from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
s=(root/'reference/CNrecipe_v1.1_interactive.html').read_text()
s=s.replace('<title>CNrecipe — Interactive Prototype V1.1</title>', '<title>CNrecipe</title>')
s=s.replace('</style>', '''
/* Device chrome belongs to iOS; prototype content geometry is retained. */
button{color:inherit}input,select,textarea{color:var(--ink)}
html,body,#app{height:100%;width:100%;overflow:hidden;background:var(--paper)}
.studio{display:block!important;margin:0!important;padding:0!important;min-height:0!important;height:100%;border-radius:0!important;background:var(--paper)}
.rail,.inspector,.status{display:none!important}.phone-shell{height:100%!important;min-height:0!important;width:100%;border:0!important;border-radius:0!important;box-shadow:none!important;background:var(--paper)}.phone{border-radius:0!important}.viewport{padding-bottom:calc(150px + env(safe-area-inset-bottom,0px))!important}.viewport.task{padding-bottom:calc(28px + env(safe-area-inset-bottom,0px))!important}.floating-nav{position:absolute;bottom:calc(12px + env(safe-area-inset-bottom,0px));padding-bottom:2px}.sheet-shade{position:absolute}.home-center{padding-top:105px}
/* Keep editable text at iOS's readable focus size; preserve prototype placeholders. */
.searchbox input,.field input,.field select,.field textarea,.setting-row select{font-size:16px;line-height:20px}
.field input,.field select,.field textarea{padding:9px 10px;min-width:0}
.field-grid .field{min-width:0}
.searchbox input::placeholder,.field input::placeholder,.field textarea::placeholder{font-size:12px}
/* Repeated control taps remain taps; scrolling and pinch zoom stay available. */
#app{touch-action:manipulation}
#storage-warning{position:fixed;top:0;left:0;right:0;z-index:100;background:#fff0e8;color:#852d1a;font-size:12px;padding:10px}
</style>''')
s=s.replace("let persisted={};try{persisted=JSON.parse(localStorage.getItem('cnrecipe-v11-state')||'{}')||{}}", "let persisted={};try{persisted=window.__nativeState ?? JSON.parse(localStorage.getItem('cnrecipe-v11-state')||'{}')||{}}")
# Parentheses required when mixing ?? and ||.
s=s.replace("window.__nativeState ?? JSON.parse(localStorage.getItem('cnrecipe-v11-state')||'{}')||{}", "window.__nativeState ?? (JSON.parse(localStorage.getItem('cnrecipe-v11-state')||'{}')||{})")
a=s.index('function persist(){');b=s.index('\nfunction selectedRecipe',a)
s=s[:a]+'''function snapshot(){return {version:1,pantry:state.pantry,shopping:[...state.shopping],saved:[...state.saved],history:[...state.history],region:state.region,units:state.units,largeText:state.largeText,allergens:[...state.allergens],ongoing:state.ongoing,selected:state.selected,servings:state.servings,checked:[...state.checked],step:state.step,rating:state.rating,cookingNote:state.cookingNote,timer:state.timer,records:state.records,completion:state.completion}}
function bridge(method,payload){if(window.webkit?.messageHandlers?.native)return window.webkit.messageHandlers.native.postMessage({method,payload});return Promise.resolve(null)}
function storageWarning(message){let el=document.getElementById('storage-warning');if(!el){el=document.createElement('div');el.id='storage-warning';el.setAttribute('role','alert');document.body.append(el)}el.textContent=message;if(window.__storageError){const button=document.createElement('button');button.textContent='Open recovery settings';button.onclick=()=>go('settings');el.append(' ',button)}document.getElementById('app').style.paddingTop=el.getBoundingClientRect().height+'px'}
function persist(){const value=snapshot();if(window.webkit?.messageHandlers?.native){bridge('save',value).catch(()=>storageWarning('Changes could not be saved. Keep the app open and try again.'))}else{try{localStorage.setItem('cnrecipe-v11-state',JSON.stringify(value))}catch(e){storageWarning('Changes could not be saved.')}}}
function scheduleTimer(){if(state.timer.running)bridge('timer',{deadline:state.timer.deadline}).catch(()=>toast('Notifications unavailable. Timer still works in the app.'));else bridge('cancelTimer',{}).catch(()=>{})}
''' + s[b:]
# restore fields that the demo discarded
anchor="const app=document.getElementById('app');"
s=s.replace(anchor,"""state.selected=recipes.some(r=>r.id===data.selected)?data.selected:'tomato';state.servings=Math.max(1,Math.min(8,Number(data.servings)||2));state.checked=new Set(Array.isArray(data.checked)?data.checked:[]);state.step=Math.max(0,Math.min(3,Number(data.step)||0));state.rating=Math.max(0,Math.min(5,Number(data.rating)||0));state.cookingNote=typeof data.cookingNote==='string'?data.cookingNote:'';state.timer=data.timer&&Number.isFinite(data.timer.remaining)&&data.timer.remaining>=0?data.timer:{deadline:null,remaining:0,running:false};state.records=Array.isArray(data.records)?data.records:[];state.completion=!!data.completion;if(state.completion)state.screen='complete';
"""+anchor)
s=re.sub(r"photo:'https://[^']+'", lambda m: "photo:'assets/"+str(len(re.findall("photo:",s[:m.start()])))+".jpg'",s)
s=s.replace("percent:4,label:'Check today'","percent:0,label:'Check today'").replace('percent:Math.max(7,percent)','percent')
s=s.replace("state.pantryFilter==='soon'?attention(i):state.pantryFilter==='undated'?!i.until:true", "state.pantryFilter==='soon'?(health(i).days!==null&&health(i).days>=0&&health(i).days<=2):state.pantryFilter==='expired'?(health(i).days!==null&&health(i).days<0):state.pantryFilter==='undated'?!i.until:true")
s=s.replace("['Needs attention','soon']","['Use soon','soon'],['Expired','expired']")
s=s.replace('state.pantry.filter(attention).length','state.pantry.filter(i=>health(i).days!==null&&health(i).days>=0&&health(i).days<=2).length').replace('ingredients need a closer look','ingredients to use soon')
s=s.replace('timerRemaining()||p[3]',"state.timer.initialized?timerRemaining():p[3]")
s=s.replace("state.timer={deadline:null,remaining:0,running:false}","state.timer={deadline:null,remaining:0,running:false,initialized:false};scheduleTimer()")
s=s.replace("state.timer={deadline:Date.now()+duration*1000,remaining:duration,running:true};render(false)","state.timer={deadline:Date.now()+duration*1000,remaining:duration,running:true,initialized:true};persist();scheduleTimer();render(false)")
s=s.replace("state.timer={deadline:null,remaining:timerRemaining(),running:false};render(false)","state.timer={deadline:null,remaining:timerRemaining(),running:false,initialized:true};persist();scheduleTimer();render(false)")
s=s.replace("state.timer.deadline=null;toast", "state.timer.deadline=null;persist();scheduleTimer();toast")
s=s.replace("state.ongoing=null;persist();go('complete')","state.ongoing=null;state.completion=true;state.rating=0;state.cookingNote='';persist();go('complete')")
s=s.replace("state.rating=Number(el.dataset.rate);render(false)","state.rating=Number(el.dataset.rate);persist();render(false)")
s=s.replace("if(el.name==='cooking-note')state.cookingNote=el.value", "if(el.name==='cooking-note'){state.cookingNote=el.value;persist()}")
s=s.replace("state.checked.add(n);render(false)","state.checked.add(n);persist();render(false)")
s=s.replace("state.servings+1);render(false)","state.servings+1);persist();render(false)").replace("state.servings-1);render(false)","state.servings-1);persist();render(false)")
s=s.replace("case 'save-completion':state.history", "case 'save-completion':if(state.completion){state.records.push({recipeId:state.selected,rating:state.rating,note:state.cookingNote,date:new Date().toISOString()});state.completion=false;}state.history")
s=s.replace("case 'delete-ingredient':state.pantry", "case 'delete-ingredient':if(!confirm('Remove this ingredient?'))break;state.pantry")
s=s.replace("localStorage.removeItem('cnrecipe-v11-state');location.reload()", "bridge('reset',{}).then(()=>{localStorage.removeItem('cnrecipe-v11-state');location.reload()}).catch(()=>storageWarning('Reset failed. Your data was kept.'))")
s=s.replace("if(!added){", "if(added>dateOffset(0)){state.formError='Added date cannot be in the future.';render(false);return}if(!added){")
s=s.replace("function chooseRecipe(id){", "function chooseRecipe(id){if(state.ongoing&&state.ongoing.recipeId!==id&&!confirm('Replace your current cooking session?'))return;")
s=s.replace("if(!recipes.some(x=>x.id===id))return;state.selected", "if(!recipes.some(x=>x.id===id))return;if(state.ongoing?.recipeId===id){state.selected=id;go('detail');return}state.ongoing=null;state.selected")
s=s.replace("function go(screen){", "function go(screen){if(screen==='prep'&&!state.ongoing){state.ongoing={recipeId:state.selected,step:0,servings:state.servings,phase:'prep'};persist()}")
s=s.replace("render(true);\n})();", "if(window.__storageError)storageWarning('Saved data could not be read. The original file was preserved.');render(true);\n})();")
s=s.replace('loading="lazy"', 'loading="eager"').replace('✳', '✳︎')
s=s.replace("state.checked=new Set(selectedRecipe().items.concat([{}]).map((_,i)=>i));render(false)","state.checked=new Set(selectedRecipe().items.concat([{}]).map((_,i)=>i));persist();render(false)")
s=s.replace("${r.time} min · ${r.level}${state.savedTab==='ongoing'?' · Resume cooking':''}</p>", "${r.time} min · ${r.level}${state.savedTab==='ongoing'?' · Resume cooking':''}</p>${state.savedTab==='history'?state.records.filter(x=>x.recipeId===r.id).map(x=>`<p class=\"sub\">${'★'.repeat(x.rating)} · ${esc(x.note)}</p>`).join(''):''}")
s=s.replace("state.servings=session.servings||2;go('cook')","state.servings=session.servings||2;go(session.phase==='prep'?'prep':'cook')")
# Keep deletion outside the checkbox: WebKit presents checkbox descendants
# as one Switch and otherwise hides the nested Remove button from iOS AX.
s=s.replace('data-shop="${esc(name)}" role="checkbox" tabindex="0" aria-checked="${checked}">',
    '><div class="shopping-check" data-shop="${esc(name)}" role="checkbox" tabindex="0" aria-label="${esc(name)}" aria-checked="${checked}">')
s=s.replace('${esc(name)}</span><button class="text-btn" data-delete-shop=', '${esc(name)}</span></div><button class="text-btn" data-delete-shop=')
s=s.replace('</style>', '.shopping-check{display:flex;align-items:center;gap:12px;flex:1;min-width:0}\n</style>')
# Include warnings in the card name because role=button flattens descendants.
s=s.replace('aria-label="Open ${esc(r.name)}"', 'aria-label="Open ${esc(r.name)}${flag.length?"; Allergy alert: "+esc(flag.join(", ")):""}"')
s=s.replace('aria-label="${i} stars" data-rate=', 'aria-label="${i} stars" aria-pressed="${state.rating===i}" data-rate=')
s=s.replace('<div class="stars">', '<div class="stars" role="group" aria-label="Current rating: ${state.rating} of 5 stars">')
# Native browser validation bubbles are not consistently exposed in WKWebView.
s=s.replace('<form id="ingredient-form" data-form="ingredient">', '<form id="ingredient-form" data-form="ingredient" novalidate>')
s=s.replace('aria-label="Edit ${esc(i.name)}, ${h.label}"', 'aria-label="Edit ${esc(i.name)}, ${esc(h.label)}, ${esc(i.qty)} · ${esc(i.storage)}"')
# Keep the live search editor attached while results change. Replacing it on
# every input discards WebKit's marked text, selection and keyboard session.
results_start=s.index('${list.length?`<div class="card-grid">')
results_end=s.index('</section>',results_start)
results_expression=s[results_start:results_end]
s=s[:results_start]+'<div id="recipe-results">${searchResults(list)}</div>'+s[results_end:]
s=s.replace('<h3>${list.length} recipes</h3>', '<h3 id="recipe-count" aria-live="polite">${list.length} recipes</h3>',1)
s=s.replace('function explore(){', '''function searchResults(list){return `'''+results_expression+'''`}
function updateSearchResults(){const count=app.querySelector('#recipe-count'),results=app.querySelector('#recipe-results');if(!count||!results)return;const list=filtered();count.textContent=`${list.length} recipes`;results.innerHTML=searchResults(list)}
const composingSearchInputs=new WeakSet();
function explore(){''',1)
old_input=s[s.index("app.addEventListener('input'"):s.index("app.addEventListener('change'")]
s=s.replace(old_input,'''app.addEventListener('compositionstart',event=>{if(event.target.matches('[name=home-search],[name=recipe-search]'))composingSearchInputs.add(event.target)});
app.addEventListener('compositionend',event=>{const el=event.target;if(!el.matches('[name=home-search],[name=recipe-search]'))return;composingSearchInputs.delete(el);state.query=el.value;if(el.name==='recipe-search')updateSearchResults()});
app.addEventListener('input',event=>{const el=event.target;if(el.name==='home-search'||el.name==='recipe-search'){if(composingSearchInputs.has(el)||event.isComposing)return;state.query=el.value;if(el.name==='recipe-search')updateSearchResults()}if(el.name==='cooking-note'){state.cookingNote=el.value;persist()}});
''')
s=s.replace("if(form.dataset.form==='search'){let input", "if(form.dataset.form==='search'){if(composingSearchInputs.has(form.querySelector('input')))return;let input")
(root/'ios/CNrecipe/Web/index.html').write_text(s)
(root/'tests/app-source.js').write_text(s.split('<script>')[1].split('</script>')[0])
