CREATE TYPE "public"."practice_mode" AS ENUM('single', 'group');
CREATE TYPE "public"."user_role" AS ENUM('admin', 'clinician');
CREATE TYPE "public"."user_status" AS ENUM('invited', 'active', 'disabled');

ALTER TABLE "tenants" ADD COLUMN IF NOT EXISTS "location" varchar(255);
ALTER TABLE "tenants" ADD COLUMN IF NOT EXISTS "specialties" jsonb DEFAULT '[]'::jsonb NOT NULL;
ALTER TABLE "tenants" ADD COLUMN IF NOT EXISTS "mode" "practice_mode" DEFAULT 'single' NOT NULL;
ALTER TABLE "tenants" ADD COLUMN IF NOT EXISTS "seats" smallint DEFAULT 1 NOT NULL;

CREATE TABLE IF NOT EXISTS "users" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"tenant_id" uuid NOT NULL,
	"firebase_uid" varchar(128),
	"email" varchar(320) NOT NULL,
	"full_name" varchar(255),
	"role" "user_role" DEFAULT 'clinician' NOT NULL,
	"status" "user_status" DEFAULT 'invited' NOT NULL,
	"invited_at" timestamp with time zone DEFAULT now() NOT NULL,
	"activated_at" timestamp with time zone,
	"created_at" timestamp with time zone DEFAULT now() NOT NULL,
	CONSTRAINT "users_firebase_uid_unique" UNIQUE("firebase_uid"),
	CONSTRAINT "users_tenant_id_tenants_id_fk" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE cascade ON UPDATE no action
);

CREATE UNIQUE INDEX IF NOT EXISTS "users_tenant_email_uq" ON "users" ("tenant_id","email");
