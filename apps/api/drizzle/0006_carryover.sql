CREATE TYPE "public"."carryover_resource_category" AS ENUM('home_practice', 'reading', 'activity', 'other');
CREATE TYPE "public"."progress_author" AS ENUM('parent', 'clinician');
CREATE TYPE "public"."progress_rating" AS ENUM('tried_it', 'going_well', 'finding_it_hard');

CREATE TABLE IF NOT EXISTS "carryover_resources" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"case_id" uuid NOT NULL,
	"title" text NOT NULL,
	"description" text,
	"url" text,
	"category" "carryover_resource_category" NOT NULL,
	"source_draft_id" uuid,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "carryover_resources_case_id_cases_id_fk" FOREIGN KEY ("case_id") REFERENCES "public"."cases"("id") ON DELETE cascade ON UPDATE no action,
	CONSTRAINT "carryover_resources_source_draft_id_ai_drafts_id_fk" FOREIGN KEY ("source_draft_id") REFERENCES "public"."ai_drafts"("id") ON DELETE set null ON UPDATE no action
);

CREATE TABLE IF NOT EXISTS "progress_entries" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"case_id" uuid NOT NULL,
	"author" "progress_author" NOT NULL,
	"note" text NOT NULL,
	"rating" "progress_rating",
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "progress_entries_case_id_cases_id_fk" FOREIGN KEY ("case_id") REFERENCES "public"."cases"("id") ON DELETE cascade ON UPDATE no action
);

CREATE TABLE IF NOT EXISTS "case_portal_links" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"case_id" uuid NOT NULL,
	"token" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"revoked_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "case_portal_links_case_id_cases_id_fk" FOREIGN KEY ("case_id") REFERENCES "public"."cases"("id") ON DELETE cascade ON UPDATE no action
);

CREATE UNIQUE INDEX IF NOT EXISTS "case_portal_links_token_unique" ON "case_portal_links" ("token");
