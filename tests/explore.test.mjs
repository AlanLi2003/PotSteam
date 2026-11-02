import {test,before,after} from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {readFile,mkdir} from 'node:fs/promises';
import {resolve,extname} from 'node:path';
import {chromium} from '@playwright/test';
const root=resolve('ios/CNrecipe/Explore'),out='artifacts/architecture-migration-20261031/browser';let server,browser;
before(async()=>{
 await mkdir(out,{recursive:true});server=createServer(async(req,res)=>{try{const p=resolve(root,'.'+new URL(req.url,'http://localhost').pathname.replace(/\/$/,'/index.html'));if(!p.startsWith(root+'/'))throw Error();const data=await readFile(p);res.writeHead(200,{'content-type':{'.html':'text/html','.js':'text/javascript','.css':'text/css','.jpg':'image/jpeg','.svg':'image/svg+xml'}[extname(p)]||'application/octet-stream'});res.end(data)}catch{res.writeHead(404);res.end()}});await new Promise(r=>server.listen(4182,'127.0.0.1',r));browser=await chromium.launch();
});after(async()=>{await browser.close();await new Promise(r=>server.close(r))});
test('shared Explore calls real cloud search; stable input, Web details and offline recovery',async()=>{
 const context=await browser.newContext({viewport:{width:393,height:720},deviceScaleFactor:1,recordVideo:{dir:out}});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:4182');await page.waitForFunction(()=>!document.getElementById('status').textContent.includes('Loading'));await page.screenshot({path:out+'/home.png'});
 await page.getByRole('button',{name:'Explore Recipes',exact:true}).click();await page.getByRole('link',{name:'Open Tomato and Egg Stir-Fry',exact:true}).waitFor();assert.equal(await page.locator('.card').count(),50);await page.waitForFunction(()=>[...document.images].filter(i=>{const r=i.getBoundingClientRect();return i.getClientRects().length && r.bottom>0 && r.top<innerHeight}).every(i=>i.complete&&i.naturalWidth>0));await page.screenshot({path:out+'/explore.png'});await page.locator('.card').last().scrollIntoViewIfNeeded();await page.waitForFunction(()=>{const i=document.querySelector('.card:last-child img');return i&&i.complete&&i.naturalWidth>0});
 const input=page.getByRole('searchbox');const handle=await input.elementHandle();await input.fill('番茄');await page.waitForFunction(()=>document.querySelectorAll('.card').length===2);assert.equal(await handle.evaluate(n=>n===document.activeElement),true);await page.screenshot({path:out+'/search-chinese.png'});
 await input.fill('unlikely-no-result-123');await page.getByRole('heading',{name:'No matching recipes'}).waitFor();await page.screenshot({path:out+'/empty.png'});await page.getByRole('button',{name:'Clear filters'}).click();await page.locator('.card').nth(5).waitFor();await page.getByRole('link',{name:'Open Tomato and Egg Stir-Fry',exact:true}).click();await page.locator('#web-detail').waitFor();assert.match(await page.locator('#web-detail').innerText(),/Tomatoes · 17.64 oz/);await page.screenshot({path:out+'/standalone-detail.png'});
 await page.getByRole('button',{name:'← Explore recipes'}).click();await page.locator('.card').nth(5).waitFor();await context.route('https://mlrerdrnwuudjsnjodkp.supabase.co/**',route=>route.abort('internetdisconnected'));await input.fill('egg');await page.getByRole('status').filter({hasText:'Offline'}).waitFor();assert.equal(await page.locator('.card').count(),50);await page.screenshot({path:out+'/offline-cached.png'});
 assert.deepEqual(errors,[]);await context.close();
});
test('small viewport, reduced motion and 44 px controls remain usable',async()=>{
 const page=await browser.newPage({viewport:{width:320,height:568},reducedMotion:'reduce'});await page.goto('http://127.0.0.1:4182');
 const check=await page.evaluate(()=>({overflow:document.documentElement.scrollWidth>innerWidth,motion:matchMedia('(prefers-reduced-motion:reduce)').matches,controls:[...document.querySelectorAll('button')].filter(b=>b.getClientRects().length).map(b=>({label:b.textContent||b.ariaLabel,height:b.getBoundingClientRect().height}))}));assert.equal(check.overflow,false);assert.equal(check.motion,true);assert.ok(check.controls.every(c=>c.height>=44));await page.screenshot({path:out+'/small-reduced-motion.png'});await page.close();
});
