import { test, expect, type APIRequestContext } from "@playwright/test";
import { e2eChildName, validIntakeAnswers } from "../fixtures/valid-intake.js";

const apiUrl = process.env.SONA_API_URL ?? "http://127.0.0.1:8081";

/**
 * Full-journey integration (DEV-34): one continuous case from registration
 * to the family portal, asserting the `cases.status` transition at every
 * observable step. Audit events are written server-side for each step
 * (patient.registered, intake.submitted, consult.booked, triage.recorded,
 * parent_summary.published, portal_link.created, portal.viewed,
 * carryover.progress_added) but there is no audit read API yet, so this spec
 * asserts their observable side effects instead: status transitions, drafts
 * appearing on the case, and the portal payload.
 */

async function getCase(request: APIRequestContext, caseId: string) {
  const res = await request.get(`${apiUrl}/v1/cases/${caseId}`);
  expect(res.status()).toBe(200);
  return (await res.json()) as {
    case: { id: string; status: string; consultAt: string | null };
    intake: { submittedAt: string | null; locked: boolean } | null;
    drafts: { kind: string }[];
  };
}

/** Book any open slot; tolerates races with parallel spec files. */
async function bookAnyOpenSlot(
  request: APIRequestContext,
  tenantId: string,
  caseId: string,
): Promise<string> {
  const from = new Date().toISOString();
  const to = new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString();
  const slotsRes = await request.get(
    `${apiUrl}/v1/clinicians/me/availability?tenantId=${tenantId}&from=${encodeURIComponent(from)}&to=${encodeURIComponent(to)}`,
  );
  expect(slotsRes.status()).toBe(200);
  const { slots } = (await slotsRes.json()) as {
    slots: { start: string; available: boolean }[];
  };
  const open = slots.filter((s) => s.available);
  expect(open.length).toBeGreaterThan(0);

  // Start at a random offset so parallel runs rarely contend for one slot.
  const offset = Math.floor(Math.random() * open.length);
  for (let i = 0; i < Math.min(open.length, 5); i++) {
    const slot = open[(offset + i) % open.length];
    const book = await request.post(`${apiUrl}/v1/cases/${caseId}/consult`, {
      data: { start: slot.start, durationMinutes: 20 },
    });
    if (book.status() === 200) {
      const { consultAt } = (await book.json()) as { consultAt: string };
      expect(new Date(consultAt).toISOString()).toBe(
        new Date(slot.start).toISOString(),
      );
      return consultAt;
    }
    expect(book.status()).toBe(409); // slot_taken race — try the next slot.
  }
  throw new Error("could not book any open consult slot");
}

test.describe("full clinical journey (API)", () => {
  test("register → intake → prep → consult → triage → plan → summary → carryover → portal", async ({
    request,
  }) => {
    const childName = e2eChildName();
    const answers = validIntakeAnswers(childName);
    const parentEmail = `e2e-journey-${Date.now()}@example.com`;

    // ── Bootstrap the automated-E2E practice ────────────────────────────
    const boot = await request.post(`${apiUrl}/v1/demo/bootstrap`, {
      data: { practice: "e2e" },
    });
    expect([200, 201]).toContain(boot.status());
    const { tenantId } = (await boot.json()) as { tenantId: string };

    // ── 1 · Clinician registers the patient; intake magic link issued ───
    const reg = await request.post(`${apiUrl}/v1/clinicians/me/patients`, {
      data: {
        tenantId,
        childFirstName: childName,
        dateOfBirth: "01 / 05 / 2019",
        parentName: "Journey Parent",
        parentEmail,
        referralSource: "gp",
        initialConcerns: "Speech delay (full-journey E2E)",
        sendIntakeLink: true,
      },
    });
    expect(reg.status()).toBe(201);
    const regBody = (await reg.json()) as {
      case: { id: string; status: string };
      intakeLink: { url: string; expiresAt: string };
    };
    const caseId = regBody.case.id;
    expect(regBody.case.status).toBe("intake_pending");
    expect(regBody.intakeLink.url).toContain("?t=");

    // ── 2 · Parent resolves the magic link ──────────────────────────────
    const token = new URL(regBody.intakeLink.url).searchParams.get("t")!;
    const resolve = await request.get(`${apiUrl}/v1/intake-links/${token}`);
    expect(resolve.status()).toBe(200);
    const resolved = (await resolve.json()) as { caseId: string; locked: boolean };
    expect(resolved.caseId).toBe(caseId);
    expect(resolved.locked).toBe(false);

    // ── 3 · Parent drafts, then submits, the intake ─────────────────────
    const draft = await request.put(`${apiUrl}/v1/cases/${caseId}/intake/draft`, {
      data: {
        answers: { ...answers, formStep: 4 },
        parentEmail,
        childDisplayName: childName,
      },
    });
    expect(draft.status()).toBe(200);
    const afterDraft = await getCase(request, caseId);
    expect(afterDraft.case.status).toBe("intake_pending");
    expect(afterDraft.intake?.submittedAt ?? null).toBeNull();
    expect(afterDraft.drafts).toEqual([]);

    const submit = await request.post(`${apiUrl}/v1/cases/${caseId}/intake`, {
      data: {
        answers,
        consentVersion: "mvp-v1",
        parentEmail,
        childDisplayName: childName,
      },
    });
    expect(submit.status()).toBe(201);

    // ── 4 · Prep brief drafted (stub); status advanced to prep_ready ────
    const afterSubmit = await getCase(request, caseId);
    expect(afterSubmit.case.status).toBe("prep_ready");
    expect(afterSubmit.intake?.submittedAt).toBeTruthy();
    expect(afterSubmit.drafts.map((d) => d.kind)).toContain("prep_brief");

    // ── 5 · Clinician books the free consult ────────────────────────────
    await bookAnyOpenSlot(request, tenantId, caseId);
    const afterBooking = await getCase(request, caseId);
    expect(afterBooking.case.consultAt).toBeTruthy();

    const ics = await request.get(`${apiUrl}/v1/cases/${caseId}/consult.ics`);
    expect(ics.status()).toBe(200);
    expect(ics.headers()["content-type"]).toContain("text/calendar");
    expect(await ics.text()).toContain("BEGIN:VCALENDAR");

    // ── 6 · Clinician triages; session plan drafted automatically ───────
    const triage = await request.post(`${apiUrl}/v1/cases/${caseId}/triage`, {
      data: { outcome: "short_block", reason: "Full-journey E2E triage" },
    });
    expect(triage.status()).toBe(200);
    const triageBody = (await triage.json()) as {
      case: { status: string };
      triage: { outcome: string };
    };
    expect(triageBody.triage.outcome).toBe("short_block");

    const afterTriage = await getCase(request, caseId);
    expect(afterTriage.case.status).toBe("plan_ready");
    expect(afterTriage.drafts.map((d) => d.kind)).toContain("session_plan");

    // ── 7 · Clinician publishes the parent summary ──────────────────────
    const summaryHtml =
      "<!DOCTYPE html><html><body><p>Full journey summary E2E</p></body></html>";
    const publish = await request.post(
      `${apiUrl}/v1/cases/${caseId}/parent-summary/publish`,
      { data: { htmlBody: summaryHtml } },
    );
    expect(publish.status()).toBe(200);
    const publishBody = (await publish.json()) as {
      case: { status: string };
      viewPath: string;
    };
    expect(publishBody.case.status).toBe("summary_sent");
    expect(publishBody.viewPath).toBe(`/v1/cases/${caseId}/parent-summary`);

    const summaryView = await request.get(
      `${apiUrl}/v1/cases/${caseId}/parent-summary`,
    );
    expect(summaryView.status()).toBe(200);
    expect(await summaryView.text()).toContain("Full journey summary E2E");

    // Publishing also drafts the clinical report for sign-off.
    const report = await request.get(`${apiUrl}/v1/cases/${caseId}/clinical-report`);
    expect(report.status()).toBe(200);

    // ── 8 · Carryover: resources shared + portal magic link ─────────────
    const resourceRes = await request.post(
      `${apiUrl}/v1/cases/${caseId}/carryover/resources`,
      {
        data: {
          title: "Daily sound practice",
          description: "Practise /s/ blends for 10 minutes a day.",
          category: "home_practice",
        },
      },
    );
    expect(resourceRes.status()).toBe(201);

    const portalLinkRes = await request.post(`${apiUrl}/v1/cases/${caseId}/portal-links`);
    expect(portalLinkRes.status()).toBe(201);
    const { token: portalToken, expiresAt } = (await portalLinkRes.json()) as {
      token: string;
      expiresAt: string;
    };
    expect(new Date(expiresAt).getTime()).toBeGreaterThan(Date.now());

    // ── 9 · Family portal shows summary + resources ─────────────────────
    const portal = await request.get(`${apiUrl}/v1/portal/${portalToken}`);
    expect(portal.status()).toBe(200);
    const payload = (await portal.json()) as {
      case: { id: string; childDisplayName: string | null; status: string };
      summary: { html: string } | null;
      resources: { title: string; category: string }[];
      progress: unknown[];
    };
    expect(payload.case.id).toBe(caseId);
    // Creating the first carryover resource (above) advances the case from
    // summary_sent → carryover (DEV-10 journey-status model).
    expect(payload.case.status).toBe("carryover");
    expect(payload.case.childDisplayName).toBe(childName);
    expect(payload.summary?.html).toContain("Full journey summary E2E");
    expect(payload.resources).toHaveLength(1);
    expect(payload.resources[0].title).toBe("Daily sound practice");

    // ── 10 · Family posts progress; clinician sees it on the case ───────
    const note = await request.post(`${apiUrl}/v1/portal/${portalToken}/progress`, {
      data: { note: "We practised every morning this week.", rating: "going_well" },
    });
    expect(note.status()).toBe(201);

    const progress = await request.get(
      `${apiUrl}/v1/cases/${caseId}/carryover/progress`,
    );
    expect(progress.status()).toBe(200);
    const { entries } = (await progress.json()) as {
      entries: { author: string; rating: string | null }[];
    };
    expect(
      entries.some((e) => e.author === "parent" && e.rating === "going_well"),
    ).toBe(true);

    // ── Final state: the journey ends at carryover with all drafts ──────
    const final = await getCase(request, caseId);
    expect(final.case.status).toBe("carryover");
    expect(final.drafts.map((d) => d.kind).sort()).toEqual([
      "clinical_report",
      "parent_summary",
      "prep_brief",
      "session_plan",
    ]);
  });
});
