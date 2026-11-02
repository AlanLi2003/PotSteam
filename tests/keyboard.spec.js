import {test,expect} from '@playwright/test';
async function bounds(page){
 const d=await page.evaluate(()=>({width:innerWidth,overflow:document.documentElement.scrollWidth,nav:(()=>{const r=document.querySelector('.floating-nav')?.getBoundingClientRect();return r&&{left:r.left,right:r.right}})()}));
 expect(d.overflow).toBeLessThanOrEqual(d.width);if(d.nav){expect(d.nav.left).toBeGreaterThanOrEqual(0);expect(d.nav.right).toBeLessThanOrEqual(d.width)}
}
for(const width of [320,393])test(`editable fields retain mobile focus sizes and fit ${width}px`,async({page:p})=>{
 await p.setViewportSize({width,height:759});await p.goto('/');
 const meta=await p.locator('meta[name=viewport]').getAttribute('content');expect(meta).not.toContain('user-scalable=no');expect(meta).not.toContain('maximum-scale=1');
 const home=p.locator('[name=home-search]');await expect(home).toHaveCSS('font-size','16px');expect(await home.evaluate(e=>getComputedStyle(e,'::placeholder').fontSize)).toBe('12px');
 await p.setViewportSize({width,height:380});await home.fill('tomato');await bounds(p);await p.getByRole('button',{name:'Search',exact:true}).click();
 const search=p.locator('[name=recipe-search]');await search.fill('egg');await expect(search).toBeFocused();await expect(search).toHaveCSS('font-size','16px');await bounds(p);
 await p.locator('.floating-nav [data-go=kitchen]').click();await p.locator('[data-action=add-ingredient]').click();
 for(const field of ['#f-name','#f-qty','#f-group','#f-storage','#f-added','#f-until'])await expect(p.locator(field)).toHaveCSS('font-size','16px');
 await p.locator('#f-name').fill('Focus test');await bounds(p);await p.getByRole('button',{name:'Close dialog'}).click();
 await p.locator('.floating-nav [data-go=explore]').click();await p.locator('[data-etab=recipes]').click();await p.locator('[data-recipe=tomato]').click();await p.locator('.page [data-go=prep]').click();await p.locator('[data-action=mark-ready]').click();await p.locator('[data-action=start-cooking]').click();for(let i=0;i<4;i++)await p.locator('[data-action=next-step]').click();
 await p.locator('#cooking-note').fill('Focus note');await expect(p.locator('#cooking-note')).toHaveCSS('font-size','16px');await bounds(p);
});
