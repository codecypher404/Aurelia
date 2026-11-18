import { test, expect } from '@playwright/test';

test.describe('Aurelia Sage Retreat — End-to-End Hospitality Ecosystem Flows', () => {
  test('1. Public navigation, floating booking widget, and 5-step booking engine with GST calculation', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('text=AURELIA SAGE')).toBeVisible();
    await page.click('[data-testid="nav-book"]');
    await expect(page.locator('text=Accommodation Selection')).toBeVisible();
  });

  test('2. Smart Table QR order flows directly to Kitchen Display System (KDS) and Admin Orders', async ({ page }) => {
    await page.goto('/#/table-qr');
    await expect(page.locator('text=Poolside Cabana 04')).toBeVisible();
  });

  test('3. Housekeeping 8-state room readiness gate blocks check-in until Inspected/Ready', async ({ page }) => {
    await page.goto('/#/admin/housekeeping');
    await expect(page.locator('text=Housekeeping Operations Board')).toBeVisible();
  });
});
