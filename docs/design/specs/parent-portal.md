# Design Spec — Secure Parent Portal / App (Non-forwardable sharing & school access)

**Linear:** DEV-108 · **Status:** Draft → In Review · **Date:** 2026-07-01
**Scope:** UK private SLT SaaS ("Sona"). Adult-facing delivery surface for reports,
session feedback, resources, homework, and video clips.
**Data:** structure only — **no PII, no publisher content**. UK English throughout.

> This spec defines *how families and schools receive clinical content securely*. It does
> not redefine the data model (DEV-101), the resource/homework hub (DEV-107), or the
> report engine (DEV-105) — it consumes them. It builds directly on **ADR-005
> (portal-first, notification-only email)** and the security/compliance work.

---

## 0. Why this exists (the problem, restated)

Delivery today is WhatsApp and email. The design partner dislikes this on privacy grounds:
child videos and reports (special-category data under UK GDPR) end up in consumer chat apps,
freely forwardable, with no access control and no audit trail. She wants a **secure parent
portal/app, free to parents**, where a family can register, complete intake, and receive
reports/resources/homework/videos — with **access-controlled sharing that prevents parents
forwarding child videos and reports**, plus a **separate access path for schools** (she only
holds school email addresses today, not named-teacher accounts).

**Non-negotiables inherited from the repo:**

- **Portal-first (ADR-005):** clinical content is rendered *only* in the authenticated
  portal. Email/SMS is **notification-only, permanently** — "a report is ready" + a sign-in
  link, never clinical content. This is a hard design rule, not a workaround.
- **PHI safety (AGENTS.md Guardrails):** no child data in email bodies, logs, or third-party
  services; audit log is append-only; clinical artifacts stay in the authenticated app/GCS.
- **No screen time for children (MVP principle #3):** every surface here is **adult-facing**
  — parent/carer, school staff, clinician. No child-facing screen.
- **Name re-attached at render (DEV-101/109):** content is stored against a Case; the
  `ClientIdentity` (PII) is joined only at render time inside the authenticated session.

---

## 1. Access model

### 1.1 Principals and roles

Three distinct principals reach content, each with its own scope. Access is **per-Case**, not
global — a principal is granted a role *on a specific Case*, never blanket access to a practice.

| Role | Who | Granted by | Scope on a Case |
|---|---|---|---|
| `parent` | The parent/carer named on intake | Clinician invite at case creation | Full family view: reports, feedback, resources, homework, videos, consent management |
| `school` | A school inbox/role (SENCO, class teacher) | Clinician invite to a **school email**; parent consent required | School-carryover view only (see §4) |
| `clinician` | The treating SLT (and future practice staff) | Practice membership + case assignment | Author/publish; sees audit; manages grants |

Roles are **additive but non-inheriting**: holding `parent` on a Case does not confer
`school`, and vice versa. A person who is somehow both (rare) needs two separate grants.

### 1.2 Parent account + magic-link fallback

- **Primary: a real parent account.** Free to the parent. Registration is initiated by a
  clinician invite (notification-only email → sign-in link). The parent sets up credentials
  via the practice identity provider (Firebase Admin, per AGENTS.md). Passkeys/WebAuthn are
  the target where the device supports them; email+password with a second factor is the
  floor. An account gives a durable, revocable identity, per-device session management, and a
  clean audit subject — the reason we move *beyond* the MVP's "case-ID-as-token" demo shortcut
  (ADR-005 explicitly defers real magic links to "a later auth ADR" — this is that step).
- **Fallback: magic link.** For parents who will not or cannot register (low digital
  confidence is common), a **single-use, short-lived, Case-scoped magic link** grants a
  session to the same portal. Properties: single-use, expiring (e.g. 15–30 min to open;
  session then time-boxed), bound to the invited email, rate-limited, and **revocable**. A
  magic-link session is a *first-class authenticated session* for audit purposes — every view
  is still logged against the invited principal.
- **Anti-forward at the link layer:** the notification email carries **no content and no
  standing secret** — only a link that resolves to a sign-in/redeem step. Forwarding the email
  forwards a challenge, not the content; redemption is logged and one of the mitigations in §2.

### 1.3 Consent capture & management

Consent is **first-class, versioned, and per-purpose** — not a single checkbox.

- **Capture at intake** (existing review-&-consent screen, DEV-101/mvp-brief): lawful basis
  (parental consent for special-category child data), plus explicit, separately-toggleable
  purposes:
  - store & process intake for triage;
  - record/receive **video clips** of the child (see teardown §2.6 — clips are real);
  - **share carryover with the child's school** (gates §4 — school access cannot be granted
    without this).
- **Manage in-portal:** a Consent screen shows each purpose, its status, when/who captured it,
  and a **withdraw** control. Withdrawing school-sharing consent immediately revokes any live
  `school` grant on the Case.
- **Audit:** every capture/change/withdrawal is an append-only audit event (§6). Consent
  version is stamped so we can prove *what* was agreed *when*.

---

## 2. Non-forwardable delivery

The core requirement: a parent can *see* a child's video/report but cannot trivially
*forward* it. We are honest that "unforwardable" is a spectrum, not an absolute — the goal is
to raise the cost and leave a trail, not to claim DRM perfection.

### 2.1 Content lives in the portal (the primary control)

- Reports, session feedback, resources, homework, and **video clips** render **inside the
  authenticated session only**. There is no public URL, no email attachment, no download
  button, and no "share" affordance for child videos/reports.
- Media (video/PDF) is served via **short-lived, session-scoped, single-use signed URLs**
  minted per view — never a durable link. A URL copied out of the network tab dies in minutes
  and is bound to the session; it is not a shareable artifact.
- **Video specifically:** streamed to an in-portal player, controls stripped of "download",
  right-click/save suppressed, and delivered as expiring segments rather than a single
  saveable file. (Confirm max clip length/consent expectations with the partner — teardown
  §5 open question 4.)

### 2.2 No download / no forward

- **Default = view-only** for all child-specific clinical content (videos, reports, session
  feedback). No download/print/export affordance is rendered for these.
- **Narrow, logged exception — reports only:** a parent may need a copy for a school/GP/EHCP
  process. If enabled by the clinician per-Case, "Get a copy of this report" produces a
  **watermarked PDF** (§2.3) via an explicit, **audited** action with a friendly warning
  ("this copy identifies your account; please share only with professionals involved in your
  child's care"). Videos are **never** downloadable. This exception is off by default.

### 2.3 Watermarking & expiry options

- **Personalised watermarking** on any rendered report/video and on the narrow report-copy
  export: a low-opacity overlay carrying the **viewing account identifier + timestamp**
  (not the child's name — name stays render-time only). A leaked screenshot/copy is then
  traceable to a grant, which is itself a deterrent.
- **Expiry / time-boxing options** (clinician-configurable per resource type): resources and
  homework are typically evergreen for the case; **video clips** can carry an expiry (e.g.
  "available for the current therapy block") after which the player shows "this clip has
  expired — ask your therapist". Grants and magic links expire independently (§1.2).

### 2.4 Screenshot risk — acknowledged, with mitigations

We **cannot** technically prevent a determined parent from screenshotting or filming their own
screen; any claim otherwise would be dishonest. Web especially has no reliable screenshot
block. Mitigations, in order of real-world value:

1. **Deterrence via attribution:** visible per-view watermark (account + timestamp) means a
   circulated capture points back to a specific grant.
2. **Audit trail:** every view of every video/report is logged (§6). We can answer "who had
   access when" for any leak investigation and for ICO defensibility.
3. **Minimise standing exposure:** expiring media URLs, no bulk export, no durable download —
   so the *easy* forward paths are closed even if the *hard* one (photographing a screen)
   isn't.
4. **Consent + expectation-setting:** the consent copy and a short first-view notice make
   explicit that content is for the family/child's care and not for onward sharing — this is
   both an ethical control and a lawful-basis anchor.
5. **App-only hardening (fast-follow, §5):** the native app can add OS screenshot
   *detection/notification* (iOS) and FLAG_SECURE screenshot *blocking* (Android) for the
   video player — a genuine capability the web portal cannot match, and a reason the app
   fast-follow matters for the most sensitive media.

> **Design honesty note for the deck:** we market this as *"private, access-controlled, and
> auditable"* — not *"impossible to copy"*. That framing is both truthful and stronger than
> WhatsApp on every axis the partner cares about.

---

## 3. What the parent sees

The parent portal is a small, calm, adult-facing surface. Home is a per-child overview; each
tile deep-links into a detail surface. All content is render-time joined to the child's name
inside the session.

| Surface | Content | Source |
|---|---|---|
| **Home / child overview** | Greeting, child summary card, "what's new" list (report ready, new homework, new clip), next session date | Case + notifications |
| **Reports** | Initial assessment, annual review, block summary — view-only, watermarked; optional audited report-copy (§2.2) | Report engine (DEV-105) |
| **Session feedback** | Per-session "N of 10" notes: what we worked on, next steps, next session date/time, **linked video clips** | Session feedback (DEV-106) + teardown §2.6 |
| **Resources** | Assigned carryover materials (Home carryover), view-only | Resource/homework hub (DEV-107) |
| **Homework / practice** | Assigned tasks with a **tick-off** ("done" toggle) + optional parent note; progress feeds the clinician | **DEV-107** homework tick-off |
| **Videos** | In-portal player, expiring, watermarked, no download | Clip store, §2 |
| **Consent** | Per-purpose consent status + withdraw controls | §1.3 |
| **Account** | Sessions/devices, sign-out, magic-link vs account status | Identity |

**Notifications (per ADR-005):** all outbound email/SMS is **content-free** — "A new
report is ready for [child's first name only, or no name] — sign in to view." No clinical
body, ever. In-portal, a "what's new" list is the real notification surface. Push (app,
fast-follow) is likewise notification-only.

**Homework tick-off (DEV-107) detail:** each assigned task shows title, brief instruction
(from the resource), a done/not-done toggle, and an optional short free-text note. Ticking a
task writes a completion event (audited) the clinician sees in the carryover view — closing
the between-session loop the partner rates as her #2 pain (mvp-brief §3).

---

## 4. School access path

Schools receive a **separate, narrower, non-inheriting** view. This is a first-class path
because the Target-Setting report already splits **Carryover for School** vs **Carryover for
Home** (teardown §2.4) — the data model already distinguishes them.

- **Grant, not an account by default.** The clinician invites a **school email** (SENCO
  inbox, class teacher). Because she only holds *school* emails today, the design must work
  with a role inbox, not a named individual: the invite creates a **`school` grant scoped to
  the one Case**, redeemable via the same magic-link mechanism (§1.2) or a lightweight school
  account if the school chooses to register.
- **Consent-gated.** A `school` grant **cannot be created** unless the parent's
  "share carryover with school" consent (§1.3) is live. Withdrawing it revokes the grant.
- **Scope: School-carryover view only.** The school sees **only** School-carryover targets,
  the resources/strategies flagged for school use, and the minimum child-identity needed to
  act (name re-attached at render, as everywhere). It does **not** see: the full report body,
  Home carryover, parent notes, video clips (unless a clip is explicitly flagged
  school-shareable and consented), consent internals, or anything else on the Case.
- **Non-inheritance (explicit):** the `school` grant is independent of the `parent` grant.
  A school never sees parent content and a parent never sees a school-private note. Revoking
  one leaves the other intact. This prevents the WhatsApp failure mode where "share with
  school" meant "forward everything".
- **Same non-forwardable controls** (§2) apply: view-only, watermarked, expiring media URLs,
  audited views.

---

## 5. Portal vs native app

**Recommendation: portal-first for v1 (default), native app as a fast-follow.**

- **v1 = responsive web portal** built on the existing Flutter web client (ADR-002; the
  parent flow already lives in `apps/sona/features/parent/`). This is the fastest path to the
  partner's actual ask — "secure, off WhatsApp" — and reuses the intake, auth, and
  notification plumbing already in the repo. It satisfies every §2 control except OS-level
  screenshot hardening.
- **Fast-follow = native app (Flutter, same codebase)** targeting the two things the web
  cannot do well: (a) **push notifications** (still content-free, ADR-005) as a gentler nudge
  than email, and (b) **screenshot blocking/detection** on the video player (§2.4 item 5) for
  the most sensitive media. The app is a hardening + convenience layer, not a re-platform.
- **Adult-facing only, both surfaces.** No child login, no gamified child screen, no child
  screen-time (MVP principle #3). The parent operates the app *for* the child; homework is
  done off-screen with the child and merely ticked off here.
- **Free to parents and schools.** Monetisation is the clinician subscription, not the family.

---

## 6. Mapping to auth / authorization + audit

Ties directly into the Speech MVP security-compliance work (AGENTS.md Guardrails; mvp-brief
Privacy stack; `docs/security/`, `docs/compliance/`).

- **AuthN.** Firebase Admin identity (existing). Parents: account (passkey/WebAuthn preferred,
  password+2FA floor) **or** single-use magic-link session. Schools: magic-link redemption or
  optional lightweight account. Clinicians: existing passkey path. Every session — including
  magic-link — is a named, auditable subject.
- **AuthZ (RBAC, per-Case).** Reuse the API's role chain (`requireIdentity` → `requireUser`
  → `requireRole`, AGENTS.md). Add **Case-scoped grants**: a principal must hold an active
  grant *(role, caseId)* to reach any content route. Enforced server-side on every
  content/media endpoint — never client-side only. `parent` and `school` are distinct grant
  types with distinct content scopes (§3, §4) and **do not inherit** one another.
- **Consent as an authZ input.** The `school`-carryover routes check live parent
  school-sharing consent (§1.3) in addition to the grant. Consent withdrawal revokes grants.
- **Media authZ.** Signed URLs are minted per view, session-scoped, single-use, short-lived
  (§2.1), and only after a grant + (for school) consent check passes.
- **Audit (append-only, 7-year retention — mvp-brief).** Log, at minimum: grant
  created/redeemed/revoked; every content **view** (report, feedback, resource, video) with
  role + caseId + principal + timestamp; homework tick events; report-copy exports (the §2.2
  exception); consent capture/change/withdrawal; magic-link issue/redeem/expiry. This is what
  makes "who accessed this child's video, and when" answerable — the capability WhatsApp can
  never provide, and the backbone of leak investigation and ICO defensibility.
- **PHI hygiene (Guardrails).** Notifications stay content-free (ADR-005); no child data in
  email/logs; audit stores identifiers/events, not clinical bodies; name join stays
  render-time inside the authenticated session.
- **DSAR / erasure (mvp-brief).** Grants, consents, and view-audit for a Case are enumerable
  and erasable via the existing DSAR/erasure endpoints; revoking access is immediate.

---

## 7. Screen / flow list (for the Figma task)

Adult-facing. Mobile 375×812 for parent; the school view is a single lightweight responsive
page. Reuse the existing design system (Inter; primary `#2D6A6E`; accent `#F2A878`; the
"AI-drafted · clinician-reviewed" pill where AI text appears).

**A. Onboarding & access (parent)**
1. `PA-01` Invite landing — "Your therapist has invited you"; trust badges (UK residency,
   HCPC, content-stays-private, adult-fills-not-child); **Create account** or **Continue with
   a one-time link**.
2. `PA-02` Account setup — passkey-first, password+2FA fallback.
3. `PA-03` Magic-link redeem / expired-link state — success vs "this link has expired, request
   a new one".
4. `PA-04` Consent screen — per-purpose toggles (process intake · receive child videos ·
   share carryover with school), version + timestamp, save.

**B. Parent portal (authenticated)**
5. `PP-01` Home / child overview — child card, "what's new" list, next session.
6. `PP-02` Reports list → `PP-03` Report detail (view-only, watermarked; audited "get a copy"
   only if enabled).
7. `PP-04` Session feedback list → `PP-05` Feedback detail (what we worked on, next steps,
   linked clips).
8. `PP-06` Video player (in-portal, expiring, watermarked, no download; expired-clip state).
9. `PP-07` Resources list → `PP-08` Resource detail (view-only).
10. `PP-09` Homework / practice — task list with **tick-off** toggle + optional note; empty
    and completed states.
11. `PP-10` Consent management — status + **withdraw** controls (incl. "withdraw school
    sharing → revokes school access" confirmation).
12. `PP-11` Account & sessions — devices, sign-out, account-vs-magic-link status.

**C. School access (separate path)**
13. `SC-01` School invite landing — role-inbox friendly; redeem one-time link or register.
14. `SC-02` School carryover view — School-carryover targets + school-flagged
    resources/strategies only; **no** report body, Home carryover, or parent content;
    view-only, watermarked.
15. `SC-03` School consent-revoked / access-ended state — "access to this pupil's carryover
    has ended".

**D. Clinician-side controls (extends existing clinician workspace)**
16. `CL-01` Case sharing panel — invite parent; invite school (email); see active grants;
    **revoke**; toggle per-Case "allow report copy".
17. `CL-02` Access & consent status — consent state per purpose; school-grant blocked banner
    when consent is absent.
18. `CL-03` Access audit view (read-only) — recent views/grants for the Case (feeds the
    append-only audit; not editable).

**E. Notifications (content-free, ADR-005)**
19. `NT-01` Email templates — "report ready", "new homework", "new clip", "invite" — link
    only, no clinical body. Push equivalents (app fast-follow) mirror these.

**Cross-cutting states to design:** loading/skeleton, empty, expired-link, revoked-access,
consent-withdrawn, and an offline/"session ended" state for magic-link sessions.

---

## 8. Open questions / follow-ups

1. **Video clip policy** — max length, retention/expiry per block, and whether any clip is
   ever school-shareable (teardown §5 Q4). Confirm with partner.
2. **Report-copy exception** — is the narrow, audited, watermarked report PDF (§2.2) wanted
   for v1, or held back until the app? Default: off.
3. **School registration uptake** — are role inboxes (magic-link only) sufficient for v1, or
   is a lightweight school account worth building early?
4. **2FA floor for parents** — acceptable given the low-digital-confidence cohort, or does
   magic-link-only need to remain a permanent equal path?
5. **App screenshot hardening scope** — video player only, or all sensitive surfaces, in the
   fast-follow?

---

## 9. Cross-references

- **ADR-005** — portal-first, notification-only email · `docs/decisions/005-portal-first-patient-communications.md`
- **AGENTS.md → Guardrails** — PHI safety, append-only audit, auth chain
- **mvp-brief.md** — Privacy stack, no-child-screen-time principle, Flutter/auth choices
- **assessment-forms-teardown.md** — School/Home carryover split (§2.4), video clips (§2.6)
- **sona-care-journey-map.md** — stages 8–9 (family summary, carryover & progress)
- Related work: **DEV-101/109** (data model, name re-attach) · **DEV-105** (report engine) ·
  **DEV-106** (session/progress) · **DEV-107** (resource/homework hub)
