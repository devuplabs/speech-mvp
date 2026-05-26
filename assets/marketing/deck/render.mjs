#!/usr/bin/env node
// Render every slide and every AI mock to a PNG using Playwright (Chromium).
//
// Outputs:
//   assets/marketing/deck/slides/<NN>.png          — 1920x1080 slide PNGs
//   assets/marketing/screenshots/ai-mocks/<id>.png — standalone mock PNGs
//
// Run:   node assets/marketing/deck/render.mjs
// Deps:  Playwright is installed under e2e/node_modules.

import { chromium } from '../../../e2e/node_modules/playwright/index.mjs';
import { readdirSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const slidesSrc = resolve(here, 'slides-src');
const slidesOut = resolve(here, 'slides');
const mocksSrc = resolve(here, '..', 'screenshots', 'ai-mocks');
const mocksOut = mocksSrc;

mkdirSync(slidesOut, { recursive: true });

const slideFiles = readdirSync(slidesSrc)
  .filter((f) => /^\d{2}-.+\.html$/.test(f))
  .sort();

const mockFiles = readdirSync(mocksSrc).filter((f) => f.endsWith('.html'));

const browser = await chromium.launch();

async function shoot(page, url, outPath, opts) {
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(200);
  await page.screenshot({ path: outPath, fullPage: opts.fullPage });
  process.stdout.write(`  -> ${outPath}\n`);
}

try {
  // Slides at exactly 1920x1080
  const slideContext = await browser.newContext({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  const slidePage = await slideContext.newPage();
  for (const f of slideFiles) {
    const url = pathToFileURL(join(slidesSrc, f)).href;
    const out = join(slidesOut, f.replace(/\.html$/, '.png'));
    await shoot(slidePage, url, out, { fullPage: false });
  }
  await slideContext.close();

  // AI mocks — full-page captures at desktop width
  const mockContext = await browser.newContext({ viewport: { width: 1300, height: 1000 }, deviceScaleFactor: 2 });
  const mockPage = await mockContext.newPage();
  for (const f of mockFiles) {
    const url = pathToFileURL(join(mocksSrc, f)).href;
    const out = join(mocksOut, f.replace(/\.html$/, '.png'));
    await shoot(mockPage, url, out, { fullPage: true });
  }
  await mockContext.close();
} finally {
  await browser.close();
}

process.stdout.write('Done.\n');
