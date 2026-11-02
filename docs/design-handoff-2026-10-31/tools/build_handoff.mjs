import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath, pathToFileURL} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const deps = process.env.CNRECIPE_DOC_NODE_MODULES;
if (!deps) throw Error('Set CNRECIPE_DOC_NODE_MODULES to the bundled workspace packages path');
const {marked} = await import(pathToFileURL(path.join(deps, 'marked/lib/marked.esm.js')));
const generated = '/Users/alanli/.codex/generated_images/01a18db1-0088-7670-b8fa-7e61e6d2cb05';
const sources = {
  'preview-a-discover.png':'exec-523e6ef8-96ad-45fe-91e8-ecb35550e84c.png',
  'preview-b-cook-corrected.png':'exec-77d044cd-ce6f-4ae0-a7a8-cacb0bfb6a63.png',
  'preview-c-support.png':'exec-0b27e1c7-f8fc-4d95-b87f-2fb56807f8be.png',
};
for (const [dest, source] of Object.entries(sources)) fs.copyFileSync(path.join(generated, source), path.join(root,'assets',dest));
const md = fs.readFileSync(path.join(root,'CNrecipe-修改说明.md'),'utf8');
let body = marked.parse(md, {gfm:true});
body = body.replace('<h1>CNrecipe 全页面优化修改说明</h1>', '<h1>CNrecipe <span style="display:inline-block">全页面优化修改说明</span></h1>');
const toc = [];
body = body.replace(/<h2>(.*?)<\/h2>/g, (_m,title)=>{
  const id = `section-${toc.length+1}`;
  toc.push(`<a href="#${id}">${title}</a>`);
  return `<h2 id="${id}">${title}</h2>`;
});
body = body.replace(/<img src="([^"]+)" alt="([^"]*)">/g, (_m,src,alt)=>{
  const file = path.resolve(root,src);
  if (!file.startsWith(root + path.sep)) throw Error('Invalid asset path');
  const mime=src.endsWith('.svg')?'image/svg+xml':'image/png';
  const url=`data:${mime};base64,${fs.readFileSync(file).toString('base64')}`;
  return `<figure><img src="${url}" alt="${alt}" tabindex="0" role="button" aria-label="放大查看 ${alt}"><figcaption>${alt} · 点击可放大查看</figcaption></figure>`;
});
body=body.replace(/<table>/g,'<div class="table-wrap"><table>').replace(/<\/table>/g,'</table></div>');
const html = `<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CNrecipe 全页面优化修改说明</title><style>
:root{color-scheme:light;--paper:#faf9f6;--ink:#272b27;--sage:#567b61;--accent:#b64e38;--line:#deded6}*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}body{margin:0;background:var(--paper);color:var(--ink);font:16px/1.85 -apple-system,BlinkMacSystemFont,'PingFang SC','Microsoft YaHei',sans-serif}.layout{max-width:1640px;margin:auto;display:grid;grid-template-columns:225px minmax(0,1fr);gap:52px;padding:40px 36px 90px}aside{position:sticky;top:24px;align-self:start;max-height:94vh;overflow:auto;font-size:13px;padding-right:14px}.brand{font-size:23px;font-weight:800;letter-spacing:-.6px;margin-bottom:20px}.brand span{color:var(--accent)}.status{font-size:12px;background:#eaf0e8;color:#34543c;border-radius:9px;padding:12px;line-height:1.7;margin-bottom:18px}nav a{display:block;padding:7px 0;color:#4e574e;text-decoration:none}nav a:hover{color:var(--accent)}main{min-width:0;max-width:1240px}h1,h2,h3{color:#000;line-height:1.35}h1{text-wrap:balance;font-size:36px;letter-spacing:-.8px;margin:0 0 16px}h2{font-size:26px;margin:55px 0 18px}h3{font-size:21px;margin:28px 0 16px}p{margin:12px 0 18px}ul,ol{padding-left:24px}li{padding:3px 0}strong{font-weight:650}figure{margin:22px 0 14px}figure img{display:block;width:100%;height:auto;border:1px solid var(--line);border-radius:14px;cursor:zoom-in;background:white}figcaption{font-size:12px;line-height:1.7;color:#62695f;margin-top:9px}.table-wrap{width:100%;overflow:auto;margin:20px 0 24px;border:1px solid #d9d9d9;border-radius:10px}table{border-collapse:collapse;min-width:650px;width:100%;font-size:14px;line-height:1.65}th{background:#e9ece6;color:#000;text-align:left;font-weight:650}td,th{padding:12px 15px;border:1px solid #d9d9d9;vertical-align:middle}tr:nth-child(even){background:#ffffff88}code{font-family:ui-monospace,monospace;font-size:.9em}main>p:first-of-type{color:#62695f;font-size:14px}main>p:nth-of-type(3){background:#edf2e9;border-radius:10px;padding:16px 20px}.footer{font-size:12px;color:#62695f;margin-top:48px}dialog{border:0;border-radius:14px;padding:0;width:96vw;max-width:1800px;background:var(--paper);max-height:96vh}dialog::backdrop{background:#1c221cc9}.dialog-head{display:flex;align-items:center;justify-content:space-between;padding:12px 18px;border-bottom:1px solid var(--line);gap:16px}.dialog-head button{border:1px solid var(--line);background:white;border-radius:8px;padding:8px 16px;cursor:pointer;flex-shrink:0}.zoom-scroll{overflow:auto;max-height:84vh;padding:10px}.zoom-scroll img{width:max(100%,1500px);max-width:none;height:auto;display:block}a:focus-visible,img:focus-visible,button:focus-visible{outline:3px solid var(--accent);outline-offset:3px}
@media(max-width:1000px){.layout{grid-template-columns:1fr;gap:24px;padding:24px 18px 50px}aside{position:static;max-height:none;padding:0}.brand{margin-bottom:8px}nav{display:flex;gap:8px;overflow:auto}nav a{white-space:nowrap;border:1px solid var(--line);border-radius:20px;padding:6px 12px}.status{margin-bottom:12px}h1{font-size:29px}h2{font-size:24px;margin-top:38px}body{font-size:15px}figure img{border-radius:8px}.zoom-scroll img{width:1500px}}
@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}@media print{.layout{display:block;max-width:none;padding:0}aside,dialog{display:none}body{background:white;font-size:10pt;line-height:1.6}h1{font-size:23pt}h2{font-size:17pt;break-after:avoid}h3{break-after:avoid}.table-wrap{overflow:visible}table{min-width:0;font-size:9pt}tr,figure{break-inside:avoid}figure img{border-radius:0}h2{margin-top:24px}a{color:inherit}}
</style></head><body><div class="layout"><aside><div class="brand">CN<span>recipe</span></div><div class="status">设计已确认<br>图标已修正<br>仅交付文档与资产</div><nav aria-label="文档目录">${toc.join('')}</nav></aside><main>${body}<div class="footer">离线图文交付 · 所有预览已内嵌 · App 实现与测试状态见第 12 节</div></main></div><dialog aria-label="放大预览"><div class="dialog-head"><span id="zoom-title"></span><button type="button">关闭预览 Esc</button></div><div class="zoom-scroll"><img alt=""></div></dialog><script>
const dlg=document.querySelector('dialog'),zoom=dlg.querySelector('img');
function expand(img){zoom.src=img.src;zoom.alt=img.alt;document.getElementById('zoom-title').textContent=img.alt;dlg.showModal()}
document.querySelectorAll('figure img').forEach(img=>{img.addEventListener('click',()=>expand(img));img.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();expand(img)}})});
dlg.querySelector('button').addEventListener('click',()=>dlg.close());
</script></body></html>`;
fs.writeFileSync(path.join(root,'CNrecipe-修改说明.html'),html);
const assetFiles = [
  ...Object.keys(sources).map(f=>`assets/${f}`),
  'assets/icon-corrections.svg',
  ...fs.readdirSync(path.join(root,'assets/icons')).map(f=>`assets/icons/${f}`),
  'CNrecipe-修改说明.md','CNrecipe-修改说明.html',
];
const manifest={version:'1.0',date:'2026-10-31',status:'design-approved-app-not-modified',files:assetFiles.map(file=>{
  const data=fs.readFileSync(path.join(root,file));
  return {path:file,bytes:data.length,sha256:crypto.createHash('sha256').update(data).digest('hex')};
})};
fs.writeFileSync(path.join(root,'manifest.json'),JSON.stringify(manifest,null,2));
console.log(JSON.stringify({htmlBytes:Buffer.byteLength(html),images:4,svgIcons:8,sections:toc.length,files:assetFiles.length}));
