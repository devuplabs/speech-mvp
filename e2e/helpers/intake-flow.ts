import { expect, type Locator, type Page } from "@playwright/test";

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

/** Build a regex that tolerates Flutter's " Tap to enter" / " DD / MM / YYYY" suffixes. */
function labelRegex(label: string | RegExp): RegExp {
  if (label instanceof RegExp) return label;
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return new RegExp(escaped, "i");
}

/**
 * Scroll the parent intake list until the target textbox enters the
 * accessibility tree. Flutter web only emits Semantics nodes for widgets
 * currently in the viewport, so fields below the fold are invisible to
 * Playwright until scrolled into view. This same effect bites human users:
 * if they don't scroll far enough they may miss a required field.
 *
 * Flutter web's GlassPane swallows raw mouse wheel events, so we scroll the
 * standard CSS scrollable container that wraps the form list directly.
 */
async function scrollListToField(page: Page, name: RegExp): Promise<Locator> {
  const field = page.getByRole("textbox", { name }).first();

  for (const direction of [+320, -320] as const) {
    for (let i = 0; i < 40; i++) {
      if ((await field.count()) > 0) {
        await field.scrollIntoViewIfNeeded().catch(() => {});
        if (await field.isVisible().catch(() => false)) return field;
      }
      const scrolled = await page.evaluate((delta) => {
        const targets = Array.from(
          document.querySelectorAll(
            "flt-scroll-cell, flt-semantics-container, flutter-view, body",
          ),
        ) as HTMLElement[];
        let total = 0;
        for (const el of targets) {
          const before = el.scrollTop;
          el.scrollTop += delta;
          total += el.scrollTop - before;
        }
        return total;
      }, direction);
      if (scrolled === 0 && direction > 0) {
        await page.keyboard.press("PageDown").catch(() => {});
      } else if (scrolled === 0) {
        break; // can't scroll up further
      }
      await page.waitForTimeout(120);
    }
  }
  throw new Error(`Could not find textbox matching ${name} after scroll sweep`);
}

/**
 * Fill a Flutter web textbox by accessibility label.
 *
 * Flutter web positions a single shared `<input>`/`<textarea>` element under
 * the focused TextField on demand. If keystrokes are dispatched before that
 * input is repositioned and focused, they fall on the wrong element (or none)
 * and Flutter's `onChanged` never fires — the DOM looks filled but the model
 * stays empty. `pressSequentially` on the locator forces focus on each press,
 * keeping the shared input in sync with the field we want to fill.
 */
export async function fillLabeledField(
  page: Page,
  name: string | RegExp,
  value: string,
) {
  const rx = labelRegex(name);
  const field = await scrollListToField(page, rx);
  await field.click();
  // Wait for Flutter to relocate the shared input; clear then sequentially type.
  await page.waitForTimeout(80);
  await field.press("ControlOrMeta+A");
  await field.press("Backspace");
  await field.pressSequentially(value, { delay: 20 });
  // Click once more to confirm focus stayed (no-op if it did); helps Flutter
  // commit any pending IME composition before we move on.
  await field.blur().catch(() => {});
}

/**
 * Continue button: clicks, then resolves with either the next step or the
 * validation snack message (so a failing test can report the real cause).
 */
export async function clickContinueAndDiagnose(
  page: Page,
  nextStep: number,
): Promise<void> {
  const snack = page
    .locator(".snack, [role=\"status\"], .MDCSnackbar, .__flt-elm-r-3")
    .or(page.getByText(/required|please|must be/i))
    .first();
  await page.getByRole("button", { name: /Continue/i }).click();
  // Wait for one of: step header changes OR a validation message appears.
  await Promise.race([
    page.getByText(`Step ${nextStep} of 8`).waitFor({ timeout: 15_000 }),
    snack.waitFor({ timeout: 15_000 }).catch(() => null),
  ]);
  if (await page.getByText(`Step ${nextStep} of 8`).isVisible().catch(() => false)) {
    return;
  }
  const visible = await page.locator("body").innerText();
  throw new Error(
    `Continue did not advance to step ${nextStep}. Visible text:\n${visible.slice(0, 1200)}`,
  );
}

/**
 * Pick a day inside the Flutter Material date picker.
 * Day buttons render as visible text like "21, Thursday, May 21, 2026, Today".
 */
export async function pickDateInOpenDialog(page: Page) {
  const ok = page.getByRole("button", { name: /^OK$/i });
  await expect(ok).toBeVisible({ timeout: 15_000 });

  const today = page.getByRole("button", { name: /, Today$/i });
  if (await today.isVisible().catch(() => false)) {
    await today.click();
  } else {
    // Click the first day in the visible grid (matches "N, Weekday, Month N, YYYY").
    const day = page
      .getByRole("button", {
        name: /^\d{1,2}, (Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), /,
      })
      .first();
    await day.click({ timeout: 10_000 });
  }

  await ok.click();
  await expect(ok).toBeHidden({ timeout: 10_000 });
}

/**
 * Open the date picker for a labeled field. Tapping the readOnly TextField in
 * Flutter web does NOT route through the GestureDetector, so the calendar
 * icon button is the only reliable way to open the picker.
 */
export async function pickDateByLabel(page: Page, label: string | RegExp) {
  const rx = labelRegex(label);
  const field = await scrollListToField(page, rx);
  // Anchor the calendar icon to its sibling textbox by walking up the DOM.
  // There may be more than one date field on a step, so prefer the one in the
  // same row as the labeled textbox.
  const fieldHandle = await field.elementHandle();
  let calendar: Locator;
  if (fieldHandle) {
    const id = await fieldHandle.evaluate((el) => {
      const row = el.closest('[role="generic"], flt-semantics, flt-semantics-container, div')
        ?.parentElement;
      if (!row) return null;
      const btn = row.querySelector('[role="button"][aria-label="Open calendar"]')
        ?? row.parentElement?.querySelector('[role="button"][aria-label="Open calendar"]');
      if (!btn) return null;
      const existing = btn.getAttribute("data-e2e-id");
      if (existing) return existing;
      const next = `cal-${Math.random().toString(36).slice(2, 8)}`;
      btn.setAttribute("data-e2e-id", next);
      return next;
    });
    calendar = id
      ? page.locator(`[data-e2e-id="${id}"]`)
      : page.getByRole("button", { name: "Open calendar" }).first();
  } else {
    calendar = page.getByRole("button", { name: "Open calendar" }).first();
  }
  await calendar.click();
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
