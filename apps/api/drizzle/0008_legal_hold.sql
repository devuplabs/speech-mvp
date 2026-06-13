-- DEV-24: Retention / legal hold on cases.
--
-- A case under a clinical-record retention duty (HCPC record-keeping, an open
-- complaint, or litigation) must refuse right-to-erasure (UK GDPR Art. 17)
-- rather than silently delete. `legal_hold` is the documented mechanism; the
-- erasure endpoint checks it and returns a clear error. See
-- docs/compliance/dsar-runbook.md.
--
-- Backwards-safe: NOT NULL with a DEFAULT false so existing rows are unaffected.
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "legal_hold" boolean DEFAULT false NOT NULL;
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "legal_hold_reason" varchar(255);
