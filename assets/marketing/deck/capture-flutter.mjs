#!/usr/bin/env node
// Best-effort Flutter web capture for the demo deck.
//
// Strategy: navigate to the launcher, click through to the parent welcome
// screen and to the clinician workspace, snapshot each. Flutter renders to
// canvas so we cannot rely on DOM selectors — we click by coordinate.
//
// On any failure the script continues so partial captures still land.

import { chromium } from '../../../e2e/node_modules/playwright/index.mjs';
import { mkdirSync } from 'node:fs';

const out = '/workspace/assets/marketing/screenshots/flutter';
mkdirSync(out, { recursive: true });

const browser = await chromium.launch();

async function captureLauncher() {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  try {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForSelector('flutter-view', { timeout: 90_000 });
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${out}/launcher.png`, fullPage: false });
    process.stdout.write(`captured launcher.png\n`);
  } catch (err) {
    process.stderr.write(`launcher capture failed: ${err.message}\n`);
  } finally {
    await ctx.close();
  }
}

async function captureParent() {
  // Parent flow uses a mobile-shaped viewport.
  const ctx = await browser.newContext({ viewport: { width: 414, height: 896 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  try {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForSelector('flutter-view', { timeout: 90_000 });
    await page.waitForTimeout(5000);
    await page.screenshot({ path: `${out}/launcher_mobile.png`, fullPage: false });

    // Click "Parent intake (mobile)" — approx centre, slightly below the logo.
    // The launcher centres a 280-wide column; on a 414 viewport the button is
    // roughly at (207, ~440).
    await page.mouse.click(207, 440);
    await page.waitForTimeout(2000);
    await page.screenshot({ path: `${out}/parent_welcome.png`, fullPage: false });
    process.stdout.write(`captured parent_welcome.png\n`);

    // Try DEV-only fill-with-sample-data and Get started.
    // ParentWelcomeScreen has a "Get started" CTA near the bottom and a tiny
    // "DEV ONLY · Fill with sample data" link below it. Coordinates below
    // are best-effort; failures are logged but not fatal.
    await page.mouse.click(207, 760);
    await page.waitForTimeout(2500);
    await page.screenshot({ path: `${out}/parent_intake_step1.png`, fullPage: false });
    process.stdout.write(`captured parent_intake_step1.png\n`);
  } catch (err) {
    process.stderr.write(`parent capture failed: ${err.message}\n`);
  } finally {
    await ctx.close();
  }
}

async function captureClinician() {
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  try {
    await page.goto('http://127.0.0.1:8080/', { waitUntil: 'domcontentloaded', timeout: 30000 });
    await page.waitForSelector('flutter-view', { timeout: 90_000 });
    await page.waitForTimeout(5000);
    // Click "Clinician workspace (desktop)" — second button just below the
    // primary on the launcher, centred at ~ (720, 400).
    await page.mouse.click(720, 400);
    await page.waitForTimeout(4000);
    await page.screenshot({ path: `${out}/clinician_today.png`, fullPage: false });
    process.stdout.write(`captured clinician_today.png\n`);

    // The clinician nav sits in a 220px left rail; "Clients" sits ~ 220px from
    // the top of the rail.
    await page.mouse.click(110, 260);
    await page.waitForTimeout(2500);
    await page.screenshot({ path: `${out}/clinician_clients.png`, fullPage: false });
    process.stdout.write(`captured clinician_clients.png\n`);
  } catch (err) {
    process.stderr.write(`clinician capture failed: ${err.message}\n`);
  } finally {
    await ctx.close();
  }
}

await captureLauncher();
await captureParent();
await captureClinician();

await browser.close();
process.stdout.write('done.\n');
