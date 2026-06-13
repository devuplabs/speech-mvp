-- DEV-10: Journey status model — cover consultation (Stage 5) and carryover
-- (Stage 9) end-to-end.
--
-- Adds two case_status enum values:
--   * consult_booked — set when a free consult is booked from prep_ready /
--     prep_drafting (between prep and triage).
--   * carryover      — set when the first home-practice resource is shared for a
--     case that has already had its parent summary sent (after summary_sent).
--
-- Backwards-safe: existing rows keep their current status; ADD VALUE only widens
-- the enum. ADD VALUE IF NOT EXISTS makes the migration idempotent on re-runs.
--
-- Postgres note: ALTER TYPE ... ADD VALUE may not run inside a transaction in
-- PG < 12, but on PG12+ (this project targets PG16) it is permitted inside a
-- transaction provided the new value is not *used* in the same transaction. This
-- migration only declares the values, so the runner's BEGIN/COMMIT wrapper is
-- safe; the values are first written by application code in later transactions.
ALTER TYPE "public"."case_status" ADD VALUE IF NOT EXISTS 'consult_booked' AFTER 'prep_ready';
ALTER TYPE "public"."case_status" ADD VALUE IF NOT EXISTS 'carryover' AFTER 'summary_sent';
