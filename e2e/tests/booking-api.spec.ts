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
  });
});
