import {
  jsonb,
  pgEnum,
  pgTable,
  text,
  timestamp,
  uuid,
  varchar,
  boolean,
  smallint,
} from "drizzle-orm/pg-core";

export const jurisdictionEnum = pgEnum("jurisdiction", ["uk", "us"]);

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

export const tenants = pgTable("tenants", {
  id: uuid("id").primaryKey().defaultRandom(),
  jurisdiction: jurisdictionEnum("jurisdiction").notNull().default("uk"),
  displayName: varchar("display_name", { length: 255 }).notNull(),
  createdAt: timestamp("created_at", { withTimezone: true }).defaultNow().notNull(),
});

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
