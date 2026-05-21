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

export async function expectStep(page: Page, step: number) {
  await expect(page.getByText(`Step ${step} of 8`)).toBeVisible({
    timeout: 30_000,
  });
}

/** Fill a Flutter web textbox by accessibility label. */
export async function fillLabeledField(
  page: Page,
  name: string | RegExp,
  value: string,
) {
  const field = page.getByRole("textbox", { name });
  await field.click();
  await field.fill(value);
}

/** Flutter Material date picker on web uses day buttons (not role=dialog). */
export async function pickDateInOpenDialog(page: Page) {
  const ok = page.getByRole("button", { name: /^OK$/i });
  await expect(ok).toBeVisible({ timeout: 15_000 });

  const today = page.getByRole("button", { name: /Today/i });
  if (await today.isVisible().catch(() => false)) {
    await today.click();
  } else {
    const day = page
      .getByRole("button", {
        name: /,( Monday| Tuesday| Wednesday| Thursday| Friday| Saturday| Sunday),/,
      })
      .first();
    await day.click({ timeout: 10_000 });
  }

  await ok.click();
}

/** Open date picker for a labeled field (textbox tap or calendar button). */
export async function pickDateByLabel(page: Page, label: RegExp) {
  const field = page.getByRole("textbox", { name: label });
  await field.click();
  if (
    !(await page
      .getByRole("button", { name: /^OK$/i })
      .isVisible()
      .catch(() => false))
  ) {
    await page.getByRole("button", { name: "Open calendar" }).click();
  }
  await pickDateInOpenDialog(page);
}

export async function tapChip(page: Page, label: string) {
  await page.getByRole("button", { name: label, exact: true }).click();
}

export async function tapYesNo(page: Page, answer: "Yes" | "No", index = 0) {
  await page
    .getByRole("button", { name: answer, exact: true })
    .nth(index)
    .click();
}

export async function assertNoApiErrorOnScreen(page: Page) {
  const apiError = page.getByText(/SonaApiException/i);
  if (await apiError.isVisible().catch(() => false)) {
    throw new Error(
      `API error on screen: ${await apiError.innerText()}. ` +
        "Hard refresh the web app or run pre-deploy-verify before merging.",
    );
  }
}

export async function openParentIntake(page: Page) {
  await waitForFlutterApp(page);
  await page.getByRole("button", { name: "Parent intake (mobile)" }).click();
  await expect(page.getByRole("button", { name: "Get started" })).toBeVisible({
    timeout: 30_000,
  });
}

/**
 * Click Get started and capture the tenantId + caseId from the network responses.
 * Returns the API base URL so callers can submit directly via the same backend.
 */
export async function getStartedCaptureCase(page: Page): Promise<{
  tenantId: string;
  caseId: string;
  apiBaseUrl: string;
}> {
  const bootstrapResp = page.waitForResponse(
    (r) =>
      r.url().includes("/v1/demo/bootstrap") &&
      r.request().method() === "POST" &&
      r.status() >= 200 &&
      r.status() < 300,
    { timeout: 90_000 },
  );
  const createCaseResp = page.waitForResponse(
    (r) =>
      r.url().includes("/v1/cases") &&
      r.request().method() === "POST" &&
      r.status() === 201,
    { timeout: 90_000 },
  );

  await page.getByRole("button", { name: "Get started" }).click();

  const boot = await bootstrapResp;
  await assertNoApiErrorOnScreen(page);
  const create = await createCaseResp;

  const bootBody = (await boot.json()) as { tenantId: string };
  const createBody = (await create.json()) as { id: string };

  await expect(page.getByText("Your details & referral")).toBeVisible({
    timeout: 30_000,
  });
  await expectStep(page, 1);

  // Derive API base URL from the actual request, so the test works against any env.
  const apiUrl = new URL(create.url());
  return {
    tenantId: bootBody.tenantId,
    caseId: createBody.id,
    apiBaseUrl: `${apiUrl.protocol}//${apiUrl.host}`,
  };
}

/**
 * Click Get started and wait for the form (legacy: pure UI flow).
 * Use {@link getStartedCaptureCase} for hybrid tests.
 */
export async function getStarted(page: Page) {
  await getStartedCaptureCase(page);
}

export async function openClinicianDashboard(page: Page) {
  await page.getByRole("button", { name: "Home" }).click();
  await expect(
    page.getByRole("button", { name: "Parent intake (mobile)" }),
  ).toBeVisible({ timeout: 30_000 });
  const listCases = page.waitForResponse(
    (r) =>
      r.url().includes("/v1/tenants/") &&
      r.url().includes("/cases") &&
      r.request().method() === "GET" &&
      r.status() === 200,
    { timeout: 60_000 },
  );
  await page
    .getByRole("button", { name: "Clinician workspace (desktop)" })
    .click();
  await listCases;
  await expect(page.getByText("Today's cases (from API)")).toBeVisible({
    timeout: 30_000,
  });
}

/**
 * Find the child's case row on the dashboard.
 * Flutter web exposes case rows as buttons with the child name inside the
 * accessibility label, so we match by role+name (text node match misses them).
 */
export function childCaseLocator(page: Page, childName: string) {
  return page
    .getByRole("button", { name: new RegExp(escapeRegex(childName), "i") })
    .first();
}

function escapeRegex(s: string) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** Click Refresh on the clinician dashboard until the case shows up. */
export async function refreshDashboardUntilChildVisible(
  page: Page,
  childName: string,
  attempts = 6,
) {
  for (let i = 0; i < attempts; i++) {
    const refresh = page.waitForResponse(
      (r) =>
        r.url().includes("/v1/tenants/") &&
        r.url().includes("/cases") &&
        r.request().method() === "GET",
      { timeout: 30_000 },
    );
    await page.getByRole("button", { name: "Refresh" }).click();
    await refresh;
    if (
      await childCaseLocator(page, childName)
        .isVisible()
        .catch(() => false)
    ) {
      return;
    }
    await page.waitForTimeout(1_000);
  }
  throw new Error(
    `Child "${childName}" did not appear on clinician dashboard after ${attempts} refresh attempts`,
  );
}

export async function expectChildOnDashboard(page: Page, childName: string) {
  await expect(childCaseLocator(page, childName)).toBeVisible({
    timeout: 60_000,
  });
  // Status label on the row is "Ready" / "Drafting" / "Triaged" — never the
  // backend value alone, so accept any non-empty status indicator.
  await expect(
    page
      .getByRole("button", { name: new RegExp(escapeRegex(childName), "i") })
      .first(),
  ).toContainText(/Ready|Drafting|Triaged|intake/i);
}
