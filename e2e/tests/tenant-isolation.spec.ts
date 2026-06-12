import { test, expect, type APIRequestContext } from "@playwright/test";
import { randomUUID } from "node:crypto";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

/**
 * Tenant isolation suite (DEV-34).
 *
 * `POST /v1/demo/bootstrap` only supports two stable variants ("demo" and
 * "e2e") and the "demo" variant carries the real canonical demo caseload, so
 * polluting it with isolation probes is not an option. Tenant A therefore
 * uses the bootstrap "e2e" variant (proving the bootstrap path), and the
 * second tenant of each pair is created via `POST /v1/tenants`, which gives a
 * fresh, fully isolated practice per run.
 *
 * Auth posture: the MVP case routes are intentionally unauthenticated (auth
 * hardening is DEV-31). What is enforceable today — and what this suite
 * proves — is that tenant-scoped *list* endpoints always filter by tenantId
 * and case-scoped sub-resources always filter by their parent caseId, so
 * substituting another tenant's identifiers can never read or mutate foreign
 * rows: the API answers 404 or an empty list, never 200-with-foreign-data
 * and never 500. Assertions that need a caller identity to be meaningful are
 * parked as test.fixme below, referencing DEV-31.
 */

async function bootstrapE2eTenant(request: APIRequestContext): Promise<string> {
  const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
    data: { practice: "e2e" },
  });
  expect([200, 201]).toContain(boot.status());
  const { tenantId } = (await boot.json()) as { tenantId: string };
  return tenantId;
}

async function createIsolatedTenant(request: APIRequestContext): Promise<string> {
  const res = await request.post(`${apiUrl}/v1/tenants`, {
    data: { displayName: `Sona E2E isolation ${randomUUID().slice(0, 8)} (automated)` },
  });
  expect(res.status()).toBe(201);
  const { id } = (await res.json()) as { id: string };
  return id;
}

async function createCase(request: APIRequestContext, tenantId: string): Promise<string> {
  const res = await request.post(`${apiUrl}/v1/cases`, {
    data: { tenantId, childDisplayName: e2eChildName() },
  });
  expect(res.status()).toBe(201);
  const { id } = (await res.json()) as { id: string };
  return id;
}

async function submitIntake(request: APIRequestContext, caseId: string) {
  const childName = e2eChildName();
  const answers = validIntakeAnswers(childName);
  const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
    data: {
      answers,
      consentVersion: "mvp-v1",
      parentEmail: answers.email,
      childDisplayName: childName,
    },
  });
  expect(submit.status()).toBe(201);
}

test.describe("tenant isolation", () => {
  test("tenant-scoped case and intake lists never include another tenant's rows", async ({
    request,
  }) => {
    const tenantA = await bootstrapE2eTenant(request);
    const tenantB = await createIsolatedTenant(request);

    const caseA = await createCase(request, tenantA);
    const caseB = await createCase(request, tenantB);

    // Tenant A sees its case; tenant B never does (and vice versa).
    const listA = await request.get(`${apiUrl}/v1/tenants/${tenantA}/cases`);
    expect(listA.status()).toBe(200);
    const casesA = ((await listA.json()) as { cases: { id: string }[] }).cases;
    expect(casesA.some((c) => c.id === caseA)).toBe(true);
    expect(casesA.some((c) => c.id === caseB)).toBe(false);

    const listB = await request.get(`${apiUrl}/v1/tenants/${tenantB}/cases`);
    expect(listB.status()).toBe(200);
    const casesB = ((await listB.json()) as { cases: { id: string }[] }).cases;
    expect(casesB.some((c) => c.id === caseB)).toBe(true);
    expect(casesB.some((c) => c.id === caseA)).toBe(false);

    // Intake-forms dashboard list is equally scoped.
    const formsB = await request.get(
      `${apiUrl}/v1/tenants/${tenantB}/intake-submissions`,
    );
    expect(formsB.status()).toBe(200);
    const itemsB = ((await formsB.json()) as { items: { caseId: string }[] }).items;
    expect(itemsB.some((i) => i.caseId === caseA)).toBe(false);
    expect(itemsB.some((i) => i.caseId === caseB)).toBe(true);

    // A guessed (never-issued) tenant id yields empty lists — not foreign
    // data and not a 500.
    const ghost = randomUUID();
    const ghostCases = await request.get(`${apiUrl}/v1/tenants/${ghost}/cases`);
    expect(ghostCases.status()).toBe(200);
    expect(((await ghostCases.json()) as { cases: unknown[] }).cases).toEqual([]);

    const ghostForms = await request.get(
      `${apiUrl}/v1/tenants/${ghost}/intake-submissions`,
    );
    expect(ghostForms.status()).toBe(200);
    expect(((await ghostForms.json()) as { items: unknown[] }).items).toEqual([]);

    const ghostReports = await request.get(
      `${apiUrl}/v1/tenants/${ghost}/clinical-reports`,
    );
    expect(ghostReports.status()).toBe(200);
    expect(((await ghostReports.json()) as { items: unknown[] }).items).toEqual([]);
  });

  test("clinical report list is tenant-scoped", async ({ request }) => {
    const tenantA = await createIsolatedTenant(request);
    const tenantB = await createIsolatedTenant(request);

    const caseA = await createCase(request, tenantA);
    await submitIntake(request, caseA);
    const triage = await request.post(`${apiUrl}/v1/cases/${caseA}/triage`, {
      data: { outcome: "short_block" },
    });
    expect(triage.status()).toBe(200);
    const gen = await request.post(
      `${apiUrl}/v1/cases/${caseA}/clinical-report/generate`,
    );
    expect(gen.status()).toBe(200);

    const reportsA = await request.get(
      `${apiUrl}/v1/tenants/${tenantA}/clinical-reports`,
    );
    expect(reportsA.status()).toBe(200);
    const itemsA = ((await reportsA.json()) as { items: { caseId: string }[] }).items;
    expect(itemsA.some((i) => i.caseId === caseA)).toBe(true);

    const reportsB = await request.get(
      `${apiUrl}/v1/tenants/${tenantB}/clinical-reports`,
    );
    expect(reportsB.status()).toBe(200);
    const itemsB = ((await reportsB.json()) as { items: { caseId: string }[] }).items;
    expect(itemsB.some((i) => i.caseId === caseA)).toBe(false);
  });

  test("carryover sub-resources cannot be read or mutated via a foreign caseId", async ({
    request,
  }) => {
    const tenantA = await createIsolatedTenant(request);
    const tenantB = await createIsolatedTenant(request);
    const caseA = await createCase(request, tenantA);
    const caseB = await createCase(request, tenantB);

    const created = await request.post(
      `${apiUrl}/v1/cases/${caseA}/carryover/resources`,
      { data: { title: "Tenant A practice pack", category: "home_practice" } },
    );
    expect(created.status()).toBe(201);
    const { resource } = (await created.json()) as { resource: { id: string } };

    const noteA = await request.post(
      `${apiUrl}/v1/cases/${caseA}/carryover/progress`,
      { data: { note: "Tenant A clinician note." } },
    );
    expect(noteA.status()).toBe(201);

    // Substituting tenant B's caseId in front of tenant A's resourceId must
    // not read, rename or delete the row.
    const crossPatch = await request.patch(
      `${apiUrl}/v1/cases/${caseB}/carryover/resources/${resource.id}`,
      { data: { title: "hijacked" } },
    );
    expect(crossPatch.status()).toBe(404);

    const crossDelete = await request.delete(
      `${apiUrl}/v1/cases/${caseB}/carryover/resources/${resource.id}`,
    );
    expect(crossDelete.status()).toBe(404);

    const listB = await request.get(`${apiUrl}/v1/cases/${caseB}/carryover/resources`);
    expect(listB.status()).toBe(200);
    expect(((await listB.json()) as { resources: unknown[] }).resources).toEqual([]);

    const progressB = await request.get(
      `${apiUrl}/v1/cases/${caseB}/carryover/progress`,
    );
    expect(progressB.status()).toBe(200);
    expect(((await progressB.json()) as { entries: unknown[] }).entries).toEqual([]);

    // Tenant A's resource is intact and un-renamed.
    const listA = await request.get(`${apiUrl}/v1/cases/${caseA}/carryover/resources`);
    expect(listA.status()).toBe(200);
    const resourcesA = ((await listA.json()) as {
      resources: { id: string; title: string }[];
    }).resources;
    expect(resourcesA).toHaveLength(1);
    expect(resourcesA[0].id).toBe(resource.id);
    expect(resourcesA[0].title).toBe("Tenant A practice pack");
  });

  test("consult bookings and availability are tenant-scoped", async ({ request }) => {
    const tenantA = await createIsolatedTenant(request);
    const tenantB = await createIsolatedTenant(request);
    const caseA = await createCase(request, tenantA);
    const caseB = await createCase(request, tenantB);

    const from = new Date().toISOString();
    const to = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
    const slotsUrl = (tenantId: string) =>
      `${apiUrl}/v1/clinicians/me/availability?tenantId=${tenantId}&from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`;

    const slotsRes = await request.get(slotsUrl(tenantA));
    expect(slotsRes.status()).toBe(200);
    const { slots } = (await slotsRes.json()) as {
      slots: { start: string; available: boolean }[];
    };
    const open = slots.find((s) => s.available);
    expect(open).toBeTruthy();

    const bookA = await request.post(`${apiUrl}/v1/cases/${caseA}/consult`, {
      data: { start: open!.start, durationMinutes: 20 },
    });
    expect(bookA.status()).toBe(200);

    // The booked slot is taken in tenant A but still free in tenant B —
    // collision checks never look across tenants.
    const afterA = await request.get(slotsUrl(tenantA));
    const slotsAfterA = ((await afterA.json()) as {
      slots: { start: string; available: boolean }[];
    }).slots;
    expect(slotsAfterA.find((s) => s.start === open!.start)?.available).toBe(false);

    const afterB = await request.get(slotsUrl(tenantB));
    expect(afterB.status()).toBe(200);
    const slotsAfterB = ((await afterB.json()) as {
      slots: { start: string; available: boolean }[];
    }).slots;
    expect(slotsAfterB.find((s) => s.start === open!.start)?.available).toBe(true);

    const bookB = await request.post(`${apiUrl}/v1/cases/${caseB}/consult`, {
      data: { start: open!.start, durationMinutes: 20 },
    });
    expect(bookB.status()).toBe(200);
  });

  test("magic-link tokens resolve only to their own case, never a foreign one", async ({
    request,
  }) => {
    const tenantA = await createIsolatedTenant(request);
    const tenantB = await createIsolatedTenant(request);

    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId: tenantA,
        childFirstName: e2eChildName(),
        dateOfBirth: "01 / 06 / 2019",
        parentName: "Isolation Parent",
        parentEmail: `e2e-isolation-${Date.now()}@example.com`,
        referralSource: "gp",
        sendIntakeLink: true,
      },
    });
    expect(reg.status()).toBe(201);
    const regBody = (await reg.json()) as {
      case: { id: string };
      intakeLink: { url: string };
    };
    const token = new URL(regBody.intakeLink.url).searchParams.get("t")!;

    const caseB = await createCase(request, tenantB);

    const resolve = await request.get(`${apiUrl}/v1/intake-links/${token}`);
    expect(resolve.status()).toBe(200);
    const resolved = (await resolve.json()) as { caseId: string };
    expect(resolved.caseId).toBe(regBody.case.id);
    expect(resolved.caseId).not.toBe(caseB);

    // Portal tokens behave the same way.
    const portalLink = await request.post(`${apiUrl}/v1/cases/${caseB}/portal-links`);
    expect(portalLink.status()).toBe(201);
    const { token: portalToken } = (await portalLink.json()) as { token: string };
    const portal = await request.get(`${apiUrl}/v1/portal/${portalToken}`);
    expect(portal.status()).toBe(200);
    const payload = (await portal.json()) as { case: { id: string } };
    expect(payload.case.id).toBe(caseB);
    expect(payload.case.id).not.toBe(regBody.case.id);
  });

  // ── Blocked on auth (DEV-31) ─────────────────────────────────────────────
  // The MVP case routes are deliberately unauthenticated, so "tenant B's
  // clinician" has no representable identity yet. Once DEV-31 lands these
  // must be enabled and pass.

  // TODO(DEV-31): with a tenant-B credential, GET /v1/cases/:caseId for a
  // tenant-A case must return 404 (not the case row, as it does today by
  // design for token-less MVP clients).
  test.fixme("cross-tenant case detail read returns 404 once auth lands (DEV-31)", async () => {});

  // TODO(DEV-31): POST /v1/cases (and /v1/clinicians/me/patients) must reject
  // a body tenantId that does not match the caller's tenant with 403.
  test.fixme("case creation rejects a foreign tenantId once auth lands (DEV-31)", async () => {});

  // TODO(DEV-31): PUT /v1/clinicians/me/availability/rules must reject a body
  // tenantId outside the caller's tenant with 403; today any caller can
  // rewrite any tenant's availability because there is no caller identity.
  test.fixme("availability rules cannot be replaced cross-tenant once auth lands (DEV-31)", async () => {});

  // TODO(DEV-31): case-scoped mutations (intake lock/resend/revoke, triage,
  // publish, carryover, portal links) must 404 for a caseId outside the
  // caller's tenant instead of relying on caseId unguessability.
  test.fixme("case-scoped mutations 404 for foreign caseIds once auth lands (DEV-31)", async () => {});
});
