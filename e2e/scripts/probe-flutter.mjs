import { chromium } from "playwright";

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 430, height: 932 } });
await page.goto("https://sona-web-dev-3rhenudy6a-nw.a.run.app/", {
  timeout: 120_000,
});
await page.waitForTimeout(20_000);
const a11y = page.locator('[aria-label="Enable accessibility"]');
if ((await a11y.count()) > 0) {
  await a11y.evaluate((el) => el.click());
}
await page.waitForTimeout(15_000);
console.log("--- body text ---");
console.log(await page.locator("body").innerText());
console.log("--- buttons ---");
console.log(await page.getByRole("button").allTextContents());
await browser.close();
