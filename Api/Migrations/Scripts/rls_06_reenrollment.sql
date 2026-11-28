-- Re-enrollment: let a signed-in student send their own enrollment for the open term.
--
-- Apply this to a database that already has row-level security from rls_02_policies.sql. It is
-- the same four policies that file now carries, pulled out so a live database can be brought
-- forward without re-running every policy. Safe to run more than once.
--
--   psql "$DATABASE_URL" -f rls_06_reenrollment.sql
--
-- WITHOUT THIS, ONLINE RE-ENROLLMENT IS BROKEN WHEREVER RLS IS ENFORCED. ReenrollmentService
-- .SubmitAsync writes four rows in one batch -- a response, an application, a form and the
-- contacts -- and every one of those tables was staff-only (app.is_staff() = roles 1,2,3,4,6).
-- A student is role 5, so Postgres refused the first insert, the whole transaction rolled back,
-- and nothing was saved. Found on 2026-11-28 by submitting as a real student against a database
-- the API was connected to as dbtc_api; it had been broken since RLS was switched on 2026-11-22.
-- No test could see it: the other suites run on the InMemory provider, which has no policies,
-- and the Postgres-backed ones connect as the table OWNER, which Postgres exempts.
--
-- Writes only, and only INSERT. A student still cannot UPDATE or DELETE any of this: once their
-- enrollment is sent, only the Registrar can change it. Reads already worked -- rls_02 gives a
-- student their own application, form and contacts through app.owns/owns_application/
-- owns_enrollment, which is what fills the form in from last term.

BEGIN;

-- The response row. Unlike the public applicant's at role -2, this one is deliberately written
-- with IsProcessed = TRUE (ReenrollmentService: "never shown in Form responses"), because
-- re-enrollment goes straight to a Pending application instead of into the Registrar's queue of
-- unprocessed Google Form responses. So the -2 policy's shape cannot be reused here: its
-- "IsProcessed = false" clause is exactly what refuses a student. Ownership is enforced on the
-- application below, which is the row that actually confers anything; a response on its own
-- names no student, grants nothing, and is invisible to the student who inserted it.
DROP POLICY IF EXISTS "EnrollmentResponses_student_insert" ON "EnrollmentResponses";
CREATE POLICY "EnrollmentResponses_student_insert" ON "EnrollmentResponses" FOR INSERT
  WITH CHECK (app.is_student() AND app.email() <> '' AND LOWER("EmailAddress") = app.email());

-- The application itself. This is where the real constraints live: a student may only create a
-- Pending, returning application for THEMSELVES. They cannot approve their own enrollment
-- (Status is pinned to 1 = Pending), and cannot file one in anybody else's name.
DROP POLICY IF EXISTS "EnrollmentApplications_student_insert" ON "EnrollmentApplications";
CREATE POLICY "EnrollmentApplications_student_insert" ON "EnrollmentApplications" FOR INSERT
  WITH CHECK (
    app.is_student()
    AND app.owns("StudentUserID")
    AND "Status" = 1
    AND "IsReturning" = true
  );

-- The form and the contacts hang off that application, so they inherit its ownership. Both
-- helpers walk back to EnrollmentApplications."StudentUserID"; the rows are inserted in the same
-- transaction, and rls_02's read policies let the student see their own, so the chain resolves.
DROP POLICY IF EXISTS "EnrollmentForms_student_insert" ON "EnrollmentForms";
CREATE POLICY "EnrollmentForms_student_insert" ON "EnrollmentForms" FOR INSERT
  WITH CHECK (app.is_student() AND app.owns_application("ApplicationID"));

DROP POLICY IF EXISTS "Contacts_student_insert" ON "Contacts";
CREATE POLICY "Contacts_student_insert" ON "Contacts" FOR INSERT
  WITH CHECK (app.is_student() AND app.owns_enrollment("EnrollmentID"));

COMMIT;

-- Checking it took, as the API's database role. Replace the two uuids with a real student's
-- UserID and the ProgramID/TermID of an open term; <email> is that student's Users.Email.
--
--   SET LOCAL ROLE dbtc_api;
--   SELECT set_config('app.role', '5', true), set_config('app.user_id', '<student uuid>', true),
--          set_config('app.email', '<email>', true);
--   -- allowed, in this order:
--   INSERT INTO "EnrollmentResponses" ("ResponseID","EmailAddress","IsProcessed","Timestamp","Data")
--   VALUES ('<resp uuid>', '<email>', true, now(), '{}'::jsonb);
--   INSERT INTO "EnrollmentApplications" ("ApplicationID","ResponseID","ProgramID","TermID","Status","CreatedAt","IsReturning","StudentUserID")
--   VALUES ('<app uuid>', '<resp uuid>', <program>, '<term uuid>', 1, now(), true, '<student uuid>');
--   -- refused, every one of them:
--   UPDATE "EnrollmentApplications" SET "Status" = 2;          -- cannot approve their own
--   DELETE FROM "EnrollmentApplications";                      -- cannot withdraw it either
--   INSERT INTO "EnrollmentApplications" (... "Status" ...) VALUES (... 2 ...);   -- not Pending
--   INSERT INTO "EnrollmentApplications" (... "StudentUserID" ...) VALUES (... '<someone else>' ...);
--
-- The honest end-to-end check is still a real submission from the Student Portal with the API
-- connected as dbtc_api, because that is the only thing that exercises all four inserts in the
-- one batch and in the order EF sends them.
