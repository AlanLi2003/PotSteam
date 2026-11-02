import {readFile,writeFile,mkdir,cp,copyFile,readdir} from 'node:fs/promises';
import {runInNewContext} from 'node:vm';
import {chromium} from '@playwright/test';
await mkdir('ios/CNrecipe/Explore',{recursive:true});await cp('web/explore','ios/CNrecipe/Explore',{recursive:true});
await cp('ios/CNrecipe/Web/assets','ios/CNrecipe/Explore/assets',{recursive:true});
await mkdir('ios/CNrecipe/Content/icons',{recursive:true});
const browser=await chromium.launch();const page=await browser.newPage({viewport:{width:24,height:24},deviceScaleFactor:3});
for(const folder of ['docs/design-handoff-2026-10-31/assets/icons','docs/content/first-50/assets/icons']) {
for(const file of (await readdir(folder)).filter(file=>file.endsWith('.svg')).sort()) {
 const name=file.slice(0,-4);
 const svg=await readFile(`${folder}/${name}.svg`,'utf8');
 await page.setContent(`<style>html,body{margin:0;color:#272B27}svg{display:block;width:24px;height:24px}</style>${svg}`);
 await page.screenshot({path:`ios/CNrecipe/Content/icons/${name}.png`,omitBackground:true});
}
}
const source=await readFile('reference/CNrecipe_v1.1_interactive.html','utf8');
const start=source.indexOf('const iconPaths='),end=source.indexOf(';',start);
const paths=runInNewContext(source.slice(start,end+1)+';iconPaths',{}, {timeout:1000});
await writeFile('ios/CNrecipe/Explore/assets/ui-settings.svg',`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="#272B27" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${paths.settings}</svg>`);
for(const name of ['home','kitchen','heart','settings','back','next','plus','check','close','leaf','clock']){
 await page.setContent(`<style>html,body{margin:0;color:#272B27}svg{display:block;width:24px;height:24px}</style><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${paths[name]}</svg>`);
 await page.screenshot({path:`ios/CNrecipe/Content/icons/nav-${name}.png`,omitBackground:true});
}
await browser.close();console.log('Explore and supplied SVG icons prepared; no icon tracing.');
