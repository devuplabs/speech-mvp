ALTER TABLE "intake_submissions"
  ADD COLUMN IF NOT EXISTS "locked" boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "updated_at" timestamptz NOT NULL DEFAULT now();

ALTER TABLE "case_intake_links"
  ADD COLUMN IF NOT EXISTS "template_id" varchar(32) NOT NULL DEFAULT 'full';
