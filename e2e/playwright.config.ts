import { defineConfig, devices } from "@playwright/test";

const webUrl =
  process.env.SONA_WEB_URL ?? "https://sona-web-dev-3rhenudy6a-nw.a.run.app";
const apiUrl =
  process.env.SONA_API_URL ?? "https://sona-api-dev-3rhenudy6a-nw.a.run.app";

export default defineConfig({
  testDir: "./tests",
  timeout: 600_000,
  expect: { timeout: 30_000 },
  fullyParallel: false,
  retries: process.env.CI ? 1 : 0,
  reporter: [["list"], ["html", { open: "never" }]],
  use: {
    baseURL: webUrl,
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
    viewport: { width: 430, height: 932 },
    ...devices["Desktop Chrome"],
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  metadata: { apiUrl },
});
