import { expect, type Page } from "@playwright/test";

/** Flutter web hides semantics until the placeholder is activated. */
export async function enableFlutterAccessibility(page: Page) {
  const a11y = page.locator('[aria-label="Enable accessibility"]');
  if ((await a11y.count()) > 0) {
    await a11y.evaluate((el) => (el as HTMLElement).click());
  }
}

/** Wait for WASM load + semantics tree (launcher or welcome). */
export async function waitForFlutterApp(page: Page) {
  await page.goto("/", { waitUntil: "domcontentloaded", timeout: 120_000 });
  await page
    .getByText("Loading Sona")
    .waitFor({ state: "hidden", timeout: 120_000 })
    .catch(() => {});
  await enableFlutterAccessibility(page);
  await expect(
    page.getByRole("button", { name: "Parent intake (mobile)" }),
  ).toBeVisible({ timeout: 90_000 });
}

/** Fill visible text fields in DOM order (Flutter web exposes native inputs). */
export async function fillVisibleTextFields(page: Page, values: string[]) {
  const fields = page.locator("input:not([readonly]), textarea");
  await expect(fields.first()).toBeVisible({ timeout: 15_000 });
  const count = await fields.count();
  for (let i = 0; i < values.length && i < count; i++) {
    await fields.nth(i).fill(values[i]);
  }
}

export async function pickFirstDateField(page: Page) {
  const dateInput = page.locator("input[readonly]").first();
  await dateInput.click();
  // Material date picker — pick enabled day then OK
  const day = page.locator('[role="gridcell"]:not([aria-disabled="true"])').first();
  await day.click({ timeout: 10_000 });
  const ok = page.getByRole("button", { name: /^OK$/i });
  if (await ok.isVisible().catch(() => false)) {
    await ok.click();
  }
}

export async function tapChip(page: Page, label: string) {
  await page.getByText(label, { exact: true }).click();
}

export async function tapYesNo(page: Page, answer: "Yes" | "No") {
  await page.getByRole("button", { name: answer }).click();
}

export async function continueStep(page: Page) {
  await page.getByRole("button", { name: /Continue/i }).click();
}

export async function openParentIntake(page: Page) {
  await waitForFlutterApp(page);
  await page.getByRole("button", { name: "Parent intake (mobile)" }).click();
  await expect(page.getByRole("button", { name: "Get started" })).toBeVisible({
    timeout: 30_000,
  });
}

export async function getStarted(page: Page) {
  const bootstrap = page.waitForResponse(
    (r) => r.url().includes("/v1/demo/bootstrap") && r.status() >= 200 && r.status() < 300,
    { timeout: 60_000 },
  );
  const createCase = page.waitForResponse(
    (r) =>
      r.url().includes("/v1/cases") &&
      r.request().method() === "POST" &&
      r.status() === 201,
    { timeout: 60_000 },
  );
  await page.getByRole("button", { name: "Get started" }).click();
  await bootstrap;
  const apiError = page.getByText(/SonaApiException/i);
  if (await apiError.isVisible().catch(() => false)) {
    throw new Error(
      `Flutter client rejected a successful API response: ${await apiError.innerText()}. ` +
        "Deploy the web build that accepts bootstrap HTTP 200 (see apps/sona/lib/services/api_client.dart).",
    );
  }
  await createCase;
  await expect(page.getByText("Your details & referral")).toBeVisible({
    timeout: 30_000,
  });
}

export async function fillStep1(page: Page) {
  const textValues = [
    "e2e.parent@example.com",
    "E2E Child",
    "5",
    "1 Test Lane, London",
    "E2E Mother",
    "",
    "07700900001",
    "mother@example.com",
    "E2E Father",
    "",
    "07700900002",
    "father@example.com",
    "Test GP",
    "GP Street",
    "02070000000",
    "School",
    "Website",
  ];
  await fillVisibleTextFields(page, textValues);
  await pickFirstDateField(page);
}

export async function fillStep2(page: Page) {
  await fillVisibleTextFields(page, ["Speech delay E2E automated test concern."]);
  await tapChip(page, "Speech sounds");
  await tapChip(page, "Staying on task");
}

export async function fillStep3(page: Page) {
  await tapYesNo(page, "No");
  await tapYesNo(page, "No");
  await fillVisibleTextFields(page, ["English", "English", "English"]);
  await tapYesNo(page, "No");
}

export async function fillStep4(page: Page) {
  await fillVisibleTextFields(page, [
    "Normal pregnancy",
    "No",
    "3.2kg",
    "None",
    "None",
  ]);
}

export async function fillStep5(page: Page) {
  await fillVisibleTextFields(page, [
    "None",
    "Good",
    "None",
    "None",
    "No",
    "Yes normal",
    "None",
    "None",
    "Yes normal",
  ]);
}

export async function fillStep6(page: Page) {
  await tapYesNo(page, "Yes");
  await fillVisibleTextFields(page, [
    "12 months",
    "18 months",
    "Variable attention",
    "Want juice",
    "Follows directions",
  ]);
}

export async function fillStep7(page: Page) {
  await fillVisibleTextFields(page, [
    "Friendly",
    "Good",
    "Plays well",
    "Blocks",
    "Some awareness",
  ]);
}

export async function fillStep8(page: Page) {
  await fillVisibleTextFields(page, [
    "Test Nursery, London",
    "Mon-Fri",
    "None",
    "",
    "E2E Parent",
  ]);
  await pickFirstDateField(page);
  await tapYesNo(page, "No");
}

export async function submitReview(page: Page) {
  const checkboxes = page.getByRole("checkbox");
  const n = await checkboxes.count();
  for (let i = 0; i < n; i++) {
    await checkboxes.nth(i).check();
  }
  const submit = page.waitForResponse(
    (r) =>
      r.url().includes("/intake") &&
      r.request().method() === "POST" &&
      !r.url().includes("/draft") &&
      r.status() >= 200 &&
      r.status() < 300,
    { timeout: 60_000 },
  );
  await page.getByRole("button", { name: /^Submit$/i }).click();
  await submit;
}
