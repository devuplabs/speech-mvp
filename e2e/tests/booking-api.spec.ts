import { test, expect } from "@playwright/test";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

test.describe("consult booking API", () => {
  test("register with bookConsult sets consult_at and ICS export", async ({ request }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    const { tenantId } = (await boot.json()) as { tenantId: string };

    const from = new Date().toISOString();
    const to = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const slotsRes = await request.get(
      `${apiUrl}/v1/clinicians/me/availability?tenantId=${tenantId}&from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
    );
    expect(slotsRes.ok()).toBeTruthy();
    const { slots } = (await slotsRes.json()) as {
      slots: { start: string; available: boolean }[];
    };
    const open = slots.find((s) => s.available);
    expect(open).toBeTruthy();

    const email = `e2e-book-${Date.now()}@example.com`;
    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId,
        childFirstName: "Booked Child",
        dateOfBirth: "01 / 06 / 2018",
        parentName: "Parent",
        parentEmail: email,
        referralSource: "gp",
        sendIntakeLink: true,
        bookConsult: { start: open!.start, durationMinutes: 20 },
      },
    });
    expect(reg.status()).toBe(201);
    const body = (await reg.json()) as {
      case: { id: string; consultAt: string | null };
      consultBooking: { consultAt: string } | null;
    };
    expect(body.consultBooking?.consultAt ?? body.case.consultAt).toBeTruthy();

    const ics = await request.get(`${apiUrl}/v1/cases/${body.case.id}/consult.ics`);
    expect(ics.ok()).toBeTruthy();
    expect(ics.headers()["content-type"]).toContain("text/calendar");
    const text = await ics.text();
    expect(text).toContain("BEGIN:VCALENDAR");
    expect(text).toContain("Booked Child");

    // Booking during registration must NOT advance status: the case still needs
    // its intake submitted, so it stays in the intake phase (DEV-10).
    const afterRegBook = await request.get(`${apiUrl}/v1/cases/${body.case.id}`);
    const afterRegBody = (await afterRegBook.json()) as { case: { status: string } };
    expect(afterRegBody.case.status).not.toBe("consult_booked");
  });

  test("booking a consult from prep_ready advances status to consult_booked", async ({
    request,
  }) => {
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, { data: {} });
    const { tenantId } = (await boot.json()) as { tenantId: string };

    // Create a case and submit intake so the worker advances it to prep_ready.
    const caseRes = await request.post(`${apiUrl}/v1/cases`, {
      data: { tenantId, childDisplayName: "Prep Ready Child" },
    });
    expect(caseRes.status()).toBe(201);
    const { id: caseId } = (await caseRes.json()) as { id: string };

    const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: { answers: { q1: "a" }, consentVersion: "mvp-v1" },
    });
    expect(submit.status()).toBe(201);
    const submitted = (await submit.json()) as { case: { status: string } };
    // Stub prep runs inline; case should be at prep_ready (or still prep_drafting).
    expect(["prep_ready", "prep_drafting"]).toContain(submitted.case.status);

    const from = new Date().toISOString();
    const to = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    const slotsRes = await request.get(
      `${apiUrl}/v1/clinicians/me/availability?tenantId=${tenantId}&from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
    );
    const { slots } = (await slotsRes.json()) as {
      slots: { start: string; available: boolean }[];
    };
    const open = slots.find((s) => s.available);
    expect(open).toBeTruthy();

    const book = await request.post(`${apiUrl}/v1/cases/${caseId}/consult`, {
      data: { start: open!.start, durationMinutes: 20 },
    });
    expect(book.status()).toBe(200);
    const booked = (await book.json()) as { case: { status: string } };
    expect(booked.case.status).toBe("consult_booked");

    // Triage is still permitted from consult_booked (booking is optional, DEV-10).
    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "strategy_only" },
    });
    expect(triage.ok()).toBeTruthy();
  });
});
