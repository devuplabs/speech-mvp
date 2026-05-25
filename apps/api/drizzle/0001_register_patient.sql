ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "parent_phone" varchar(64);
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "referral_source" varchar(32);

CREATE TABLE IF NOT EXISTS "case_intake_links" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"case_id" uuid NOT NULL,
	"token" text NOT NULL,
	"expires_at" timestamp with time zone NOT NULL,
	"used_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "case_intake_links_case_id_cases_id_fk" FOREIGN KEY ("case_id") REFERENCES "public"."cases"("id") ON DELETE cascade ON UPDATE no action
);

CREATE UNIQUE INDEX IF NOT EXISTS "case_intake_links_token_unique" ON "case_intake_links" ("token");
