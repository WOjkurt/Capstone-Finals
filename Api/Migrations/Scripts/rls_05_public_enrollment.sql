-- Public enrollment: let an applicant with no account submit a form.
--
-- Apply this to a database that already has row-level security from rls_02_policies.sql. It is
-- the same two policies that file now carries, pulled out so a live database can be brought
-- forward without re-running every policy. Safe to run more than once.
--
--   psql "$DATABASE_URL" -f rls_05_public_enrollment.sql
--
-- Role -2 is the public applicant. It is published by PublicEnrollmentController and by nothing
-- else: it is never stored on a user, RoleUtils.IsValidRole rejects it, and no sign-in produces
-- it. Reference tables are already readable to it, because their policy is app.role() <> 0 and
-- -2 is not 0 -- that is what lets the page ask whether enrollment is open and list the courses.

BEGIN;

DROP POLICY IF EXISTS "EnrollmentResponses_read" ON "EnrollmentResponses";
CREATE POLICY "EnrollmentResponses_read" ON "EnrollmentResponses" FOR SELECT
  USING (app.is_staff() OR app.role() = -1 OR app.role() = -2 OR app.owns_response("ResponseID"));

-- Add an unprocessed response, and nothing else. No update, no delete, and IsProcessed false so
-- a stranger cannot post something that looks already dealt with.
DROP POLICY IF EXISTS "EnrollmentResponses_public_insert" ON "EnrollmentResponses";
CREATE POLICY "EnrollmentResponses_public_insert" ON "EnrollmentResponses" FOR INSERT
  WITH CHECK (app.role() = -2 AND "IsProcessed" = false);

COMMIT;

-- Checking it took, as the API's database role:
--
--   SET LOCAL ROLE dbtc_api;
--   SELECT set_config('app.role', '-2', true);
--   -- allowed:
--   INSERT INTO "EnrollmentResponses" ("ResponseID","EmailAddress","IsProcessed","Timestamp","Data")
--   VALUES (gen_random_uuid(), 'applicant@example.com', false, now(), '{}'::jsonb);
--   -- refused, every one of them:
--   INSERT INTO "EnrollmentResponses" ("ResponseID","EmailAddress","IsProcessed","Timestamp","Data")
--   VALUES (gen_random_uuid(), 'applicant@example.com', true, now(), '{}'::jsonb);
--   UPDATE "EnrollmentResponses" SET "IsProcessed" = true;
--   DELETE FROM "EnrollmentResponses";
--   SELECT * FROM "Users";
