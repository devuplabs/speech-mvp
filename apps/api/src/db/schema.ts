import {
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
  "triaged",
  "plan_drafting",
  "plan_ready",
  "summary_sent",
]);

export const aiDraftKindEnum = pgEnum("ai_draft_kind", [
  "prep_brief",
  "session_plan",
  "parent_summary",
  "clinical_report",
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
  referralSource: varchar("referral_source", { length: 32 }),
  consultAt: timestamp("consult_at", { withTimezone: true }),
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

export const auditLog = pgTable("audit_log", {
  id: uuid("id").primaryKey().defaultRandom(),
  tenantId: uuid("tenant_id").references(() => tenants.id),
  caseId: uuid("case_id").references(() => cases.id),
  actor: varchar("actor", { length: 320 }).notNull(),
  action: varchar("action", { length: 128 }).notNull(),
  metadata: jsonb("metadata").default({}),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});
