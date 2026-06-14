import { test, expect } from "@playwright/test";

// Audit-log coverage + append-only + retention export endpoints — DEV-25.
// Hermetic: bootstraps the e2e demo practice, creates a case, exercises the
// read-access audit (with de-dupe), the admin audit-history export, and the
// retention-purge dry run. The DB-level append-only trigger is proven by the
// apps/api integration suite; this spec proves the API surface end-to-end.

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

type Json = Record<string, unknown>;

test.describe("Audit log API (DEV-25)", () => {
  test("read-access is audited and de-duped; admin export returns the trail", async ({
    request,
  }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
      data: { practice: "e2e" },
    });
    expect([200, 201]).toContain(boot.status());
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: { tenantId, childDisplayName: "Audit Smoke" },
    });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = (await caseRes.json()) as { id: string };

    // View the case three times in quick succession — should collapse to ONE
    // case.viewed event within the de-dupe window.
    for (let i = 0; i < 3; i++) {
      const view = await request.get(`${apiUrl}/v1/cases/${caseId}`);
      expect(view.status()).toBe(200);
    }

    const exportRes = await request.get(`${apiUrl}/v1/cases/${caseId}/audit-log`);
    expect(exportRes.status()).toBe(200);
    const bundle = (await exportRes.json()) as {
      meta: Json;
      entries: { action: string }[];
    };
    expect(bundle.meta.kind).toBe("case_audit_export");

    const viewedCount = bundle.entries.filter(
      (e) => e.action === "case.viewed",
    ).length;
    expect(viewedCount).toBe(1); // de-duped despite three GETs
    expect(bundle.entries.some((e) => e.action === "case.created")).toBe(true);

    // The export endpoint audits itself.
    const exportRes2 = await request.get(
      `${apiUrl}/v1/cases/${caseId}/audit-log`,
    );
    const bundle2 = (await exportRes2.json()) as {
      entries: { action: string }[];
    };
    expect(bundle2.entries.some((e) => e.action === "audit_log.exported")).toBe(
      true,
    );
  });

  test("retention purge dry run reports a cutoff and deletes nothing", async ({
    request,
  }) => {
    const res = await request.post(
      `${apiUrl}/v1/admin/audit-log/retention-purge`,
    );
    expect(res.status()).toBe(200);
    const body = (await res.json()) as {
      cutoff: string;
      deleted: number;
      dryRun: boolean;
    };
    expect(body.dryRun).toBe(true);
    // Fresh demo data is well within 7 years, so nothing is due for deletion.
    expect(body.deleted).toBe(0);
    expect(new Date(body.cutoff).getUTCFullYear()).toBeLessThan(
      new Date().getUTCFullYear(),
    );
  });
});
