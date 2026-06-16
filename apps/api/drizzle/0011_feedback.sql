-- DEV-55: in-app tester feedback collection (UAT "comment from this page").
--
-- Stores TEXT-ONLY feedback submitted from the app during user testing. By
-- design this table holds NO PHI: only the page route *pattern* (never a
-- concrete URL/token), role, journey stage, build/env metadata, and the
-- tester's free-text comment. No screenshots or other capture (product
-- decision).
--
-- tenant_id is a plain uuid with NO foreign key on purpose: a stale or unknown
-- tenant id from a test client must never fail the insert (feedback submission
-- must not error out the tester), and feedback is not tenant-owned data.
CREATE TABLE IF NOT EXISTS "feedback" (
  "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  "tenant_id" uuid,
  "role" varchar(32),
  "route" varchar(128),
  "journey_stage" varchar(64),
  "feedback_type" varchar(32) NOT NULL,
  "severity" varchar(32),
  "comment" text NOT NULL,
  "build_sha" varchar(64),
  "app_env" varchar(32),
  "viewport" varchar(32),
  "locale" varchar(35),
  "user_agent" varchar(512),
  "request_id" varchar(64),
  "created_at" timestamptz DEFAULT now() NOT NULL
);
