import { test, expect } from '@playwright/test';

test('031/032 ingredient form submits from a short viewport and survives reload', async ({page}) => {
  await page.setViewportSize({width:393,height:430});
  await page.goto('/');
  await page.locator('.floating-nav [data-go=kitchen]').click();
  await page.locator('[data-action=add-ingredient]').click();
  await page.getByLabel('Ingredient name',{exact:true}).fill('PM50 keyboard ingredient');
  await page.getByRole('button',{name:'Add to kitchen',exact:true}).click();
  await expect(page.getByRole('button',{name:/Edit PM50 keyboard ingredient/})).toHaveCount(1);
  await page.reload();
  await page.locator('.floating-nav [data-go=kitchen]').click();
  await expect(page.getByRole('button',{name:/Edit PM50 keyboard ingredient/})).toHaveCount(1);
});

test('053 can return from the bottom of details after removing every favorite', async ({page}) => {
  await page.goto('/');
  await page.locator('.floating-nav [data-go=saved]').click();
  while (await page.locator('.saved-row').count()) {
    await page.locator('.saved-row').first().click();
    await page.locator('[data-action=toggle-save]').click();
    await page.getByRole('button',{name:'Back',exact:true}).click();
    await page.locator('.floating-nav [data-go=saved]').click();
  }
  await expect(page.getByText('Nothing here yet',{exact:true})).toBeVisible();
  await page.reload();await page.locator('.floating-nav [data-go=saved]').click();
  await expect(page.getByText('Nothing here yet',{exact:true})).toBeVisible();
});

test('049 shopping empty state is independently reachable and persists', async ({page}) => {
  await page.goto('/');await page.locator('.floating-nav [data-go=kitchen]').click();
  await page.locator('[data-ktab=shopping]').click();
  while(await page.locator('[data-delete-shop]').count())await page.locator('[data-delete-shop]').first().click();
  await expect(page.getByText('Your shopping list is empty',{exact:true})).toBeVisible();
  await page.reload();await page.locator('.floating-nav [data-go=kitchen]').click();await page.locator('[data-ktab=shopping]').click();
  await expect(page.getByText('Your shopping list is empty',{exact:true})).toBeVisible();
});

test('074 timer shows its visible tip before advancing and permits Back', async ({page}) => {
  await page.clock.install();
  await page.goto('/');await page.locator('[data-etab=recipes]').click();await page.locator('[data-recipe=tomato]').click();
  await page.locator('.page [data-go=prep]').click();await page.locator('[data-action=mark-ready]').click();await page.locator('[data-action=start-cooking]').click();await page.locator('[data-action=next-step]').click();await page.locator('[data-action=start-timer]').click();
  await page.clock.runFor(5100);
  const tip=page.getByRole('status');
  await expect(tip).toHaveText('Timer done — advancing to next step');await expect(tip).toBeVisible();
  await expect(page.locator('#timer-readout')).toHaveText('00:00');await expect(page.locator('.step-box h2')).toHaveText('Cook the eggs');
  await page.screenshot({path:'artifacts/pm-50-fixes/browser-074-tip.png'});
  await page.clock.runFor(1500);await expect(page.locator('.step-box h2')).toHaveText('Cook the tomatoes');
  await page.locator('[data-action=prev-step]').click();await expect(page.locator('.step-box h2')).toHaveText('Cook the eggs');
});
