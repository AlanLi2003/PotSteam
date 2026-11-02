import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const project=path.resolve(root,'../..');
const deps=process.env.CNRECIPE_DOC_NODE_MODULES;
const {chromium}=await import(pathToFileURL(path.join(deps,'playwright/index.mjs')));
const browser=await chromium.launch({headless:true});
const context=await browser.newContext({viewport:{width:1440,height:1000},offline:true});
const page=await context.newPage();
const errors=[],requests=[];
page.on('pageerror',error=>errors.push(error.message));
page.on('request',request=>{if(/^https?:/.test(request.url()))requests.push(request.url())});
await page.goto(pathToFileURL(path.join(root,'CNrecipe-修改说明.html')).href);
await page.evaluate(()=>Promise.all([...document.images].map(i=>i.decode().catch(()=>null))));
const images=await page.locator('figure img').evaluateAll(imgs=>imgs.map(i=>({alt:i.alt,loaded:i.complete&&i.naturalWidth>0,width:i.naturalWidth,height:i.naturalHeight,embedded:i.src.startsWith('data:')})));
const desktopOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
const qa=path.join(root,'qa');fs.mkdirSync(qa,{recursive:true});
await page.screenshot({path:path.join(qa,'desktop-opening.png')});
const boundaries=await page.evaluate(()=>{
  const items=[...document.querySelectorAll('main>h2')];
  return items.map((el,i)=>({id:el.id,title:el.textContent,top:Math.max(0,Math.floor(el.getBoundingClientRect().top+scrollY-12)),bottom:Math.ceil(i+1<items.length?items[i+1].getBoundingClientRect().top+scrollY-20:document.documentElement.scrollHeight)}));
});
for (const item of boundaries) await page.screenshot({path:path.join(qa,`${item.id}.png`),fullPage:true,clip:{x:255,y:item.top,width:1175,height:Math.max(100,item.bottom-item.top)}});
await page.locator('figure img').first().click();
const dialogOpened=await page.locator('dialog').evaluate(el=>el.open);
await page.keyboard.press('Escape');
const dialogClosed=await page.locator('dialog').evaluate(el=>!el.open);
await page.setViewportSize({width:390,height:844});
await page.evaluate(()=>scrollTo(0,0));
await page.screenshot({path:path.join(qa,'mobile-opening.png')});
const mobileOverflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);
await page.goto(pathToFileURL(path.join(root,'assets/icon-corrections.svg')).href);
await page.setViewportSize({width:1200,height:560});
await page.screenshot({path:path.join(qa,'icon-corrections.png')});
await browser.close();

const expected={
 'ios/CNrecipe/App.swift':'7121ffb1a022559028e3724d3cb621c6e92f20dcbe21930f84aead293dec8e40',
 'ios/CNrecipe/Web/index.html':'e4f334c65e56147dc6b13afcb00f2fb00f06ff43c0a1965cc44caf6e8b72e8e9',
 'reference/CNrecipe_v1.1_interactive.html':'cad40ccd63410137bab268d82739aaea48c9add9bb2d5f756da40a842d3ea699',
 'scripts/build-web.py':'65d3550b0ff700f70c09b5f7593843d7b0fdba97b5bc1d2819103440ef5e1ce3',
 'tests/app-source.js':'52bed7f89a2b358c7ee62459dd673b8cb9c90d98a1b5b66be75db962b945f031',
};
const sourceChecks=Object.entries(expected).map(([file,sha])=>({file,unchanged:crypto.createHash('sha256').update(fs.readFileSync(path.join(project,file))).digest('hex')===sha}));
const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'),'utf8'));
const assetChecks=manifest.files.map(f=>({file:f.path,valid:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,f.path))).digest('hex')===f.sha256}));
const report={date:'2026-10-31',verificationScope:'Document and assets only; no app build or app business tests executed',images,sections:boundaries.length,desktopOverflow,mobileOverflow,dialogOpened,dialogClosed,externalRequests:requests,pageErrors:errors,sourceChecks,assetChecks,visualReview:'pending'};
fs.writeFileSync(path.join(root,'delivery-checks.json'),JSON.stringify(report,null,2));
const passed=images.length===4&&images.every(i=>i.loaded&&i.embedded)&&boundaries.length===12&&!desktopOverflow&&!mobileOverflow&&dialogOpened&&dialogClosed&&!requests.length&&!errors.length&&sourceChecks.every(s=>s.unchanged)&&assetChecks.every(s=>s.valid);
console.log(JSON.stringify({passed,images:images.length,sections:boundaries.length,desktopOverflow,mobileOverflow,dialogOpened,dialogClosed,sourceUnchanged:sourceChecks.every(s=>s.unchanged),pageErrors:errors,qaFolder:qa}));
if(!passed)process.exitCode=1;
