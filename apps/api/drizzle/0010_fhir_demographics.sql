-- DEV-27 / ADR-006 §5 (P0): FHIR R4 / UK Core export demographics.
--
-- So the FHIR export layer never *fabricates* clinical data, capture the
-- structured demographics UK Core mandatory-quality resources need:
--   * structured child given/family name  -> Patient.name (HumanName)
--   * child date of birth                 -> Patient.birthDate
--   * structured parent/carer name        -> RelatedPerson.name
--   * parent relationship to the child    -> RelatedPerson.relationship
--
-- All additive and nullable: existing rows are unaffected and the mapper treats
-- absent fields as absent (optional) rather than guessing. `child_display_name`
-- is retained as a legacy/derived convenience string.
--
-- Deferred (ADR-006 §5): P1 (child gender, NHS number, clinician HCPC id +
-- structured name, versioned Questionnaire, coded SLT concern) and P2
-- (richer Consent, AI Provenance, local CodeSystem URIs) are documented in
-- apps/api/src/fhir/README intent and not implemented here.

-- Idempotent: Postgres has no `CREATE TYPE IF NOT EXISTS`, so guard with a DO
-- block. Defence-in-depth alongside the advisory lock in migrate.ts so a partial
-- / re-run state can't fail on an already-existing type.
DO $$ BEGIN
  CREATE TYPE "public"."parent_relationship" AS ENUM('parent', 'mother', 'father', 'guardian', 'carer', 'other');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "child_given_name" varchar(128);
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "child_family_name" varchar(128);
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "child_dob" date;
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "parent_given_name" varchar(128);
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "parent_family_name" varchar(128);
ALTER TABLE "cases" ADD COLUMN IF NOT EXISTS "parent_relationship" "public"."parent_relationship";
