import {test,expect} from '@playwright/test';

test('search preserves the live editor, caret and composing text',async({page:p})=>{
 const errors=[];p.on('pageerror',e=>errors.push(e.message));
 await p.goto('/');await p.locator('[data-etab=recipes]').click();
 const search=p.locator('[name=recipe-search]');await search.focus();
 await search.evaluate(e=>{window.originalSearch=e});
 await search.pressSequentially('eggs');
 expect(await search.evaluate(e=>e===window.originalSearch)).toBe(true);
 await expect(search).toHaveValue('eggs');await expect(search).toBeFocused();
 await expect(p.locator('[data-recipe]')).toHaveCount(2);
 await search.evaluate(e=>e.setSelectionRange(0,4));await search.pressSequentially('tomato');
 await expect(search).toHaveValue('tomato');await expect(p.locator('[data-recipe]')).toHaveCount(1);
 for(let i=0;i<6;i++)await search.press('ArrowLeft');await search.pressSequentially('x');
 await expect(search).toHaveValue('xtomato');
 expect(await search.evaluate(e=>e.selectionStart)).toBe(1);
 await search.fill('');
 await search.evaluate(e=>{
  e.dispatchEvent(new CompositionEvent('compositionstart',{bubbles:true,data:''}));
  e.value='番';e.dispatchEvent(new InputEvent('input',{bubbles:true,isComposing:true,data:'番',inputType:'insertCompositionText'}));
  e.value='番茄';e.dispatchEvent(new InputEvent('input',{bubbles:true,isComposing:true,data:'番茄',inputType:'insertCompositionText'}));
 });
 expect(await search.evaluate(e=>e===window.originalSearch)).toBe(true);
 await expect(search).toHaveValue('番茄');await expect(p.locator('[data-recipe]')).toHaveCount(6);
 await p.locator('[data-form=search]').evaluate(f=>f.requestSubmit());
 await expect(search).toBeFocused();expect(await search.evaluate(e=>e===window.originalSearch)).toBe(true);
 await search.evaluate(e=>e.dispatchEvent(new CompositionEvent('compositionend',{bubbles:true,data:'番茄'})));
 await expect(p.locator('[data-recipe]')).toHaveCount(1);await expect(p.locator('[data-recipe=tomato]')).toBeVisible();
 await search.press('Backspace');await expect(search).toHaveValue('番');
 await search.press('ControlOrMeta+A');await search.press('Backspace');
 await expect(search).toHaveValue('');await expect(p.locator('[data-recipe]')).toHaveCount(6);
 // Leaving a composing editor must not block the replacement search field.
 await search.evaluate(e=>e.dispatchEvent(new CompositionEvent('compositionstart',{bubbles:true})));
 await p.locator('[data-etab=home]').click();await p.locator('[data-etab=recipes]').click();
 await search.pressSequentially('egg');await expect(search).toHaveValue('egg');
 await expect(p.locator('[data-recipe]')).toHaveCount(2);
 expect(errors).toEqual([]);
});

test('repeated servings actions retain limits and leave viewport zoom available',async({page:p})=>{
 await p.goto('/');
 const viewport=await p.locator('meta[name=viewport]').getAttribute('content');
 expect(viewport).not.toContain('user-scalable=no');expect(viewport).not.toContain('maximum-scale=1');
 await p.locator('[data-etab=recipes]').click();await p.locator('[data-recipe=rice]').click();
 for(let i=0;i<12;i++)await p.locator('[data-action=servings-up]').click();
 await expect(p.locator('.stepper b')).toHaveText('8');
 for(let i=0;i<12;i++)await p.locator('[data-action=servings-down]').click();
 await expect(p.locator('.stepper b')).toHaveText('1');
});
