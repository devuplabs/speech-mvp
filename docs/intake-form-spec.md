# Speech Sanctuary — Parent/Carer Intake Form (Original)

**Source:** `E:\devup\customer\intake-forms\page1.pdf` … `page8.pdf` (Google Form export, May 2026)  
**Form title:** Confidential Speech & Language Parent/Carer Questionnaire  
**Pages:** 8  
**Brand:** Speech Sanctuary — *Breathe | Speak | Be*

This document captures the **original** questionnaire for redesign (Figma → API → Flutter). Do not store real PHI in the repo.

---

## Page 1 — Contact, child & referral

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Email | email (record with response) | Yes | Pre-filled from magic link / account |
| Consent blurb | static | — | See copy below; Speech Sanctuary logo in original form |
| Consent — privacy | static | — | "The information you provide on this form will not be released to parties outside this agency without your consent." |
| Consent — permission to assess | static | — | "By completing and signing this form, you grant the therapist permission to carry out an assessment of your child's speech and language needs, and use the information to provide relevant advice and input." |
| Child's Name | short text | Yes | |
| Date of Birth | date (MM/DD/YYYY) | Yes | |
| Child's Age at time of referral | short text | Yes | |
| Address | short text | Yes | Child address |
| Mother's Name | short text | Yes | |
| Mother's Address if different | short text | No | |
| Mother's Mobile number | short text | Yes | |
| Mother's email address | short text | Yes | |
| Father's name | short text | No | |
| Father's address if different | short text | No | |
| Father's mobile number | short text | Yes | |
| Father's email address | short text | Yes | |
| GP Details (practice, address, contact) | long text | Yes | Split in API: `gp_practice`, `gp_address`, `gp_phone` |
| Who referred your child to Speech Sanctuary? | short text | Yes | |
| How did you hear about Speech Sanctuary? | short text | Yes | |

---

## Page 2 — Reason for referral & difficulty checklist

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| Main concern (free text) | long text | Yes | Section: *Reason for Referral* |
| Difficulty with (tick all) | multi-select | Yes | Options below |

**Difficulty options (multi-select) — all items required in UI:**

*Speech & language*
- Speech sounds
- Saying longer words
- Expressing ideas clearly
- Understanding what is said to them
- Following directions/instructions

*Attention & listening*
- Sitting or standing still
- Staying on task
- Maintaining focus
- Ignoring distractions appropriately
- Overly sensitive to sounds/noises

*Social skills*
- Maintaining eye contact
- Turn taking
- Sharing
- Playing with others appropriately
- Staying on topic of conversation
- Reading between the lines

*Reading & writing*
- Maintaining interest in story books
- Understanding stories and answering questions
- Reading and spelling words
- Letter/number formation
- Writing stories

---

## Page 3 — Background & language

| Field | Type | Required | Conditional |
|-------|------|----------|-------------|
| Assessed by other professionals? | Yes/No | Yes | |
| If yes — professional name & reason | long text | No | Show if Yes |
| Received / receiving therapy? | Yes/No | Yes | |
| If yes — therapy details | long text | No | Show if Yes |
| Languages child exposed to | long text | Yes | |
| Language/s spoken by parents | long text | Yes | |
| Language/s spoken by child | long text | Yes | |
| Family history of SLT/learning/attention difficulties? | Yes/No | Yes | |
| If yes — explain | long text | No | Show if Yes |

---

## Page 4 — Pregnancy & birth

| Field | Type | Required |
|-------|------|----------|
| Mother's health during pregnancy | long text | Yes |
| Premature? If yes, how many weeks | long text | Yes |
| Baby's weight at birth | long text | Yes |
| Complications during birth | long text | Yes |
| Complications after birth | long text | Yes |

---

## Page 5 — General health & sensory

| Field | Type | Required |
|-------|------|----------|
| Early childhood illnesses (details) | long text | Yes |
| General health | long text | Yes |
| Known diagnosis/syndrome (or under investigation) | long text | Yes |
| Regular medications | long text | Yes |
| Hospitalised? (details if yes) | long text | Yes |
| Hearing tested? (when & outcome) | long text | Yes |
| History of ear infections | long text | Yes |
| Ear surgery / ENT involvement | long text | Yes |
| Eyes tested? (when & outcome) | long text | Yes |

---

## Page 6 — Speech & language history

| Field | Type | Required |
|-------|------|----------|
| Responds to own name? | Yes/No | Yes |
| Age of first words | short text | Yes |
| Age of first 2-word combinations | short text | Yes |
| Attention and listening skills (description) | long text | Yes |
| Form simple/complex sentences? (examples) | long text | Yes |
| How child shows they understand you | long text | Yes |

---

## Page 7 — Social/behavioural development

| Field | Type | Required |
|-------|------|----------|
| Describe child in general (temperament) | long text | Yes |
| Social skills with familiar/unfamiliar people | long text | Yes |
| Interaction with peers | long text | Yes |
| Favourite play activities / motivating toys | long text | Yes |
| Recognises their communication needs? | long text | Yes |

---

## Page 8 — Education & sign-off

| Field | Type | Required |
|-------|------|----------|
| Current place of education (name & address) | long text | Yes |
| Nursery days/times (if applicable) | long text | No |
| Special Educational Needs / plan / EHCP | long text | Yes |
| Anything else about your child | long text | No |
| May child be photographed/filmed? | Yes/No | Yes |
| Form completed by | short text | Yes |
| Date of completion | date/text | Yes |

**Closing copy:** Thank you + communication journey message.

---

## UX / redesign notes (for Figma + Flutter)

1. **Group by section** matching Google pages (8 steps) — align with existing `Step X of 8` in `parent_form_screen.dart`.
2. **Conditional fields** — hide “If yes…” until Yes selected (professionals, therapy, family history).
3. **Yes/No + details** — replace long-text-only health questions with radio + optional detail where possible.
4. **Multi-select chips** — Page 2 checklist maps to current `SonaSelectChip` pattern.
5. **GP composite** — three fields in UI; one object in API.
6. **Consent** — Page 1 privacy + Page 8 media consent + review-screen legal guardian checkboxes (existing `parent_review_screen.dart`).
7. **Save & exit** — wire draft persistence (currently stubbed).
8. **PHI** — all fields sensitive; UK GDPR; no logging of answers.

---

## Current MVP gap

| Area | Today | Target |
|------|--------|--------|
| Flutter parent form | 8-step flow, save & exit, edit-from-review | Magic-link auth, autosave debounce |
| API intake | `PUT …/intake/draft` + validated `POST …/intake` | Per-tenant auth, encryption at rest |
| Figma | Full parent workflow (v3 verified) | — |

**Figma file:** [Speech Therapy MVP — Intake + First Session Co-Pilot](https://www.figma.com/design/OBPcwy4hIS79EQYbK8URBM/Speech-Therapy-MVP-%E2%80%94-Intake---First-Session-Co-Pilot)

**Reference PDFs:** `E:\devup\customer\intake-forms\`  
**PDF page screenshots (optional):** `E:\devup\customer\intake-forms\intake-pdf-pages\`
