-- DEV-25: Make `audit_log` append-only (tamper-evident audit trail).
--
-- Healthcare accountability (UK GDPR Art. 5(2), HCPC record-keeping) requires
-- that the audit trail cannot be quietly altered or deleted by the application.
-- We enforce this in the database with two complementary layers of defence:
--
--   1. A BEFORE UPDATE/DELETE trigger that RAISES unless the session has opted
--      in via a GUC (see below). This is the AUTHORITATIVE control: a trigger
--      fires even for the table OWNER and a SUPERUSER, so it holds regardless of
--      how the app role is provisioned. In Cloud SQL the app role (sona_app)
--      OWNS the schema, so a privilege REVOKE on the owner is the wrong tool
--      (and would actually defeat the escape hatch — see note on layer 2); the
--      trigger is what governs the owner/app role.
--
--   2. REVOKE UPDATE, DELETE ON audit_log FROM PUBLIC. This strips the
--      default-granted mutate privileges from every *non-owner* role (e.g. a
--      future read-only reporting/analytics role), giving a privilege-level
--      backstop where it is actually enforced. We deliberately do NOT revoke
--      from the owner `sona_app`: Postgres checks table privileges BEFORE
--      firing the trigger, so revoking from the owner would raise
--      "permission denied" and block the legitimate escape-hatch UPDATE/DELETE
--      below — leaving the trigger to govern the owner instead.
--
-- The escape hatch (option (b) in DEV-25): DSAR right-to-erasure (DEV-24) must
-- scrub PHI from `audit_log.metadata` and detach `case_id` on the retained
-- accountability rows (see services/dsar.ts + docs/compliance/dsar-runbook.md).
-- Rather than run erasure as a higher-privileged role, the trigger allows
-- exactly that operation when the running transaction sets
-- `SET LOCAL sona.audit_scrub = 'on'`. The flag is transaction-scoped (LOCAL),
-- so it cannot leak to other requests on a pooled connection, and erasure is the
-- only code path that sets it. Retention/archival deletion (DEV-25 §retention)
-- uses the same mechanism via `sona.audit_retention = 'on'`.
--
-- INSERTs are never restricted — the app must keep writing audit events.

REVOKE UPDATE, DELETE ON "audit_log" FROM PUBLIC;

CREATE OR REPLACE FUNCTION "audit_log_append_only"() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN
  -- DSAR PHI-scrub escape hatch: a single UPDATE that removes PHI from the
  -- retained accountability rows. Only erasure sets this transaction-local flag.
  IF TG_OP = 'UPDATE' AND current_setting('sona.audit_scrub', true) = 'on' THEN
    RETURN NEW;
  END IF;
  -- Retention/archival escape hatch: deletion of rows past the 7-year window.
  IF TG_OP = 'DELETE' AND current_setting('sona.audit_retention', true) = 'on' THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'audit_log is append-only; % is not permitted', TG_OP
    USING ERRCODE = 'check_violation',
          HINT = 'Audit rows are immutable. PHI scrub (DSAR) and 7-year retention deletion are the only exceptions and run via a dedicated, audited code path.';
END;
$$;

DROP TRIGGER IF EXISTS "audit_log_append_only" ON "audit_log";
CREATE TRIGGER "audit_log_append_only"
  BEFORE UPDATE OR DELETE ON "audit_log"
  FOR EACH ROW EXECUTE FUNCTION "audit_log_append_only"();
