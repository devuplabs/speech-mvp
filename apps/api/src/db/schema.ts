import {
  date,
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
  boolean,
  smallint,
} from "drizzle-orm/pg-core";

export const jurisdictionEnum = pgEnum("jurisdiction", ["uk", "us"]);

/** Practice billing/onboarding mode (Feature 1 — single vs group practice). */
export const practiceModeEnum = pgEnum("practice_mode", ["single", "group"]);

/** Seat role — admin (practice manager / lead clinician) vs clinician (Feature 2). */
export const userRoleEnum = pgEnum("user_role", ["admin", "clinician"]);

/** Provisioning state of a seat (Feature 4). */
export const userStatusEnum = pgEnum("user_status", ["invited", "active", "disabled"]);

export const caseStatusEnum = pgEnum("case_status", [
  "intake_pending",
  "intake_submitted",
  "prep_drafting",
  "prep_ready",
  // Stage 5 — a free consult has been booked (between prep and triage).
  "consult_booked",
  "triaged",
  "plan_drafting",
  "plan_ready",
  "summary_sent",
  // Stage 9 — carryover: home-practice resources shared after the summary.
  "carryover",
]);

export const aiDraftKindEnum = pgEnum("ai_draft_kind", [
  "prep_brief",
  "session_plan",
  "parent_summary",
  "clinical_report",
]);

/** Carryover (Stage 9) — home-practice resource categories. */
export const carryoverResourceCategoryEnum = pgEnum("carryover_resource_category", [
  "home_practice",
  "reading",
  "activity",
  "other",
]);

export const progressAuthorEnum = pgEnum("progress_author", ["parent", "clinician"]);

export const progressRatingEnum = pgEnum("progress_rating", [
  "tried_it",
  "going_well",
  "finding_it_hard",
]);

/**
 * Relationship of the parent/carer contact to the child (DEV-27, ADR-006 §5 P0).
 * Maps to `RelatedPerson.relationship` (UK Core PersonRelationshipType /
 * HL7 RoleCode value set). Captured so the FHIR export can state *who* the
 * contact is to the child rather than fabricating it.
 */
export const parentRelationshipEnum = pgEnum("parent_relationship", [
  "parent",
  "mother",
  "father",
  "guardian",
  "carer",
  "other",
]);

/**
 * A tenant is a **practice** (Feature 1). `displayName` is the practice name.
 * Multiple clinicians (see `users`) belong to one tenant and share patient
 * access (cases are tenant-scoped, never siloed per clinician).
 */
export const tenants = pgTable("tenants", {
  id: uuid("id").primaryKey().defaultRandom(),
  jurisdiction: jurisdictionEnum("jurisdiction").notNull().default("uk"),
  displayName: varchar("display_name", { length: 255 }).notNull(),
  /** Free-text UK location shown across clinician dashboards (Feature 3). */
  location: varchar("location", { length: 255 }),
  /** Practice specialties, e.g. ["Paediatric", "Dysphagia"]. */
  specialties: jsonb("specialties").$type<string[]>().notNull().default([]),
  /** single = solo clinician, group = multi-clinician practice. */
  mode: practiceModeEnum("mode").notNull().default("single"),
  /** Number of seats purchased — drives seat-based billing (Feature 1). */
  seats: smallint("seats").notNull().default(1),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

/**
 * A seat within a practice — one row per clinician/admin login (Feature 2 & 4).
 * `firebaseUid` links the row to a Firebase Authentication user once the
 * clinician has accepted their invite; it is null while status = 'invited'.
 */
export const users = pgTable(
  "users",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    tenantId: uuid("tenant_id")
      .notNull()
      .references(() => tenants.id, { onDelete: "cascade" }),
    firebaseUid: varchar("firebase_uid", { length: 128 }).unique(),
    email: varchar("email", { length: 320 }).notNull(),
    fullName: varchar("full_name", { length: 255 }),
    role: userRoleEnum("role").notNull().default("clinician"),
    status: userStatusEnum("status").notNull().default("invited"),
    invitedAt: timestamp("invited_at", { withTimezone: true }).defaultNow().notNull(),
    activatedAt: timestamp("activated_at", { withTimezone: true }),
    createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  },
  (table) => ({
    // Email is unique within a practice (the same person could exist in two practices).
    tenantEmailUq: uniqueIndex("users_tenant_email_uq").on(table.tenantId, table.email),
  }),
);

export const cases = pgTable("cases", {
  id: uuid("id").primaryKey().defaultRandom(),
  tenantId: uuid("tenant_id")
    .notNull()
    .references(() => tenants.id, { onDelete: "cascade" }),
  status: caseStatusEnum("status").notNull().default("intake_pending"),
  parentEmail: varchar("parent_email", { length: 320 }),
  parentPhone: varchar("parent_phone", { length: 64 }),
  childDisplayName: varchar("child_display_name", { length: 128 }),
  /**
   * Structured child name (DEV-27, ADR-006 §5 P0). `childDisplayName` is kept as
   * a derived/legacy convenience string, but a single display string cannot be
   * safely split into a FHIR `HumanName`; the export reads given/family from
   * these columns and only falls back to display when they are absent.
   */
  childGivenName: varchar("child_given_name", { length: 128 }),
  childFamilyName: varchar("child_family_name", { length: 128 }),
  /** Child date of birth (DEV-27, ADR-006 §5 P0) → `Patient.birthDate`. */
  childDob: date("child_dob"),
  /** Structured parent/carer name (DEV-27, ADR-006 §5 P0) → `RelatedPerson.name`. */
  parentGivenName: varchar("parent_given_name", { length: 128 }),
  parentFamilyName: varchar("parent_family_name", { length: 128 }),
  /** Parent/carer relationship to the child (DEV-27, ADR-006 §5 P0). */
  parentRelationship: parentRelationshipEnum("parent_relationship"),
  referralSource: varchar("referral_source", { length: 32 }),
  consultAt: timestamp("consult_at", { withTimezone: true }),
  /**
   * Legal/retention hold (DEV-24). When true the case is under a clinical-record
   * retention duty (e.g. HCPC record-keeping standards, an open complaint or
   * litigation) and right-to-erasure requests MUST be refused with a clear
   * error rather than silently honoured. See docs/compliance/dsar-runbook.md.
   */
  legalHold: boolean("legal_hold").notNull().default(false),
  /** Free-text reason a hold was placed (no PHI) — surfaced to the admin on refusal. */
  legalHoldReason: varchar("legal_hold_reason", { length: 255 }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});


export const clinicianAvailability = pgTable("clinician_availability", {
  id: uuid("id").primaryKey().defaultRandom(),
  tenantId: uuid("tenant_id")
    .notNull()
    .references(() => tenants.id, { onDelete: "cascade" }),
  weekday: smallint("weekday").notNull(),
  startMinuteLocal: smallint("start_minute_local").notNull(),
  endMinuteLocal: smallint("end_minute_local").notNull(),
  timezone: text("timezone").notNull().default("Europe/London"),
  active: boolean("active").notNull().default(true),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const caseIntakeLinks = pgTable("case_intake_links", {
  id: uuid("id").primaryKey().defaultRandom(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => cases.id, { onDelete: "cascade" }),
  token: text("token").notNull().unique(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  usedAt: timestamp("used_at", { withTimezone: true }),
  templateId: varchar("template_id", { length: 32 }).notNull().default("full"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

/** Branching intake answers (JSON from form engine). */
export const intakeSubmissions = pgTable("intake_submissions", {
  id: uuid("id").primaryKey().defaultRandom(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => cases.id, { onDelete: "cascade" }),
  answers: jsonb("answers").notNull().default({}),
  consentVersion: varchar("consent_version", { length: 64 }),
  locked: boolean("locked").notNull().default(false),
  submittedAt: timestamp("submitted_at", { withTimezone: true }),
  updatedAt: timestamp("updated_at", { withTimezone: true }).defaultNow().notNull(),
});

export const triageRecords = pgTable("triage_records", {
  id: uuid("id").primaryKey().defaultRandom(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => cases.id, { onDelete: "cascade" }),
  outcome: varchar("outcome", { length: 64 }).notNull(),
  reason: text("reason"),
  recordedAt: timestamp("recorded_at", { withTimezone: true }).defaultNow().notNull(),
});

/** Clinician-reviewed AI artifacts; never auto-sent. */
export const aiDrafts = pgTable("ai_drafts", {
  id: uuid("id").primaryKey().defaultRandom(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => cases.id, { onDelete: "cascade" }),
  kind: aiDraftKindEnum("kind").notNull(),
  content: jsonb("content").notNull().default({}),
  modelId: varchar("model_id", { length: 128 }),
  reviewedAt: timestamp("reviewed_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

/** Home-practice resources the clinician shares with the family (Stage 9 — Carryover). */
export const carryoverResources = pgTable("carryover_resources", {
  id: uuid("id").primaryKey().defaultRandom(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => cases.id, { onDelete: "cascade" }),
  title: text("title").notNull(),
  description: text("description"),
  url: text("url"),
  category: carryoverResourceCategoryEnum("category").notNull(),
  sourceDraftId: uuid("source_draft_id").references(() => aiDrafts.id, {
    onDelete: "set null",
  }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

/** Home-practice log — parents write via the portal, clinicians via the app. */
export const progressEntries = pgTable("progress_entries", {
  id: uuid("id").primaryKey().defaultRandom(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => cases.id, { onDelete: "cascade" }),
  author: progressAuthorEnum("author").notNull(),
  note: text("note").notNull(),
  rating: progressRatingEnum("rating"),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

/**
 * Magic links for the family portal. Unlike `caseIntakeLinks` these are
 * durable — reusable until expiry (default 90 days) and explicitly revocable;
 * there is no single-use `usedAt` semantics.
 */
export const casePortalLinks = pgTable("case_portal_links", {
  id: uuid("id").primaryKey().defaultRandom(),
  caseId: uuid("case_id")
    .notNull()
    .references(() => cases.id, { onDelete: "cascade" }),
  token: text("token").notNull().unique(),
  expiresAt: timestamp("expires_at", { withTimezone: true }).notNull(),
  revokedAt: timestamp("revoked_at", { withTimezone: true }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

export const auditLog = pgTable("audit_log", {
  id: uuid("id").primaryKey().defaultRandom(),
  tenantId: uuid("tenant_id").references(() => tenants.id),
  caseId: uuid("case_id").references(() => cases.id),
  actor: varchar("actor", { length: 320 }).notNull(),
  action: varchar("action", { length: 128 }).notNull(),
  metadata: jsonb("metadata").default({}),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

/**
 * In-app tester feedback (DEV-55) — "comment from this page" during UAT.
 *
 * TEXT-ONLY and PHI-safe by construction: only the route *pattern* (never a
 * concrete URL/token), role, journey stage, build/env metadata, and the
 * tester's free-text comment. `tenantId` is intentionally NOT a foreign key —
 * a stale/unknown tenant id must never fail a submission, and feedback is not
 * tenant-owned data. There is deliberately no PHI column here.
 */
export const feedback = pgTable("feedback", {
  id: uuid("id").primaryKey().defaultRandom(),
  tenantId: uuid("tenant_id"),
  role: varchar("role", { length: 32 }),
  route: varchar("route", { length: 128 }),
  journeyStage: varchar("journey_stage", { length: 64 }),
  feedbackType: varchar("feedback_type", { length: 32 }).notNull(),
  severity: varchar("severity", { length: 32 }),
  comment: text("comment").notNull(),
  buildSha: varchar("build_sha", { length: 64 }),
  appEnv: varchar("app_env", { length: 32 }),
  viewport: varchar("viewport", { length: 32 }),
  locale: varchar("locale", { length: 35 }),
  userAgent: varchar("user_agent", { length: 512 }),
  requestId: varchar("request_id", { length: 64 }),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});
