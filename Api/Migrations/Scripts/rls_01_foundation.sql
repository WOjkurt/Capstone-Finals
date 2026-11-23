-- Row-level security, part 1: the pieces every policy depends on.
--
-- Who enforces what:
--   dbtc_app  owns the tables and runs migrations. Postgres exempts a table's owner from its
--             own policies, and we deliberately do NOT use FORCE ROW LEVEL SECURITY, so
--             migrations and backfills keep working exactly as before.
--   dbtc_api  is the runtime role the API connects as. It owns nothing, so policies apply in
--             full. Pointing the connection string back at dbtc_app disables RLS entirely --
--             that is the rollback, and it needs no code change and no migration.

CREATE SCHEMA IF NOT EXISTS app;

-- current_setting(..., true) returns NULL rather than erroring when the setting is absent,
-- which is what makes these safe to call from a session the interceptor never touched.

CREATE OR REPLACE FUNCTION app.user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid
$$;

CREATE OR REPLACE FUNCTION app.role() RETURNS int
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(NULLIF(current_setting('app.role', true), '')::int, 0)
$$;

CREATE OR REPLACE FUNCTION app.firebase_uid() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT COALESCE(NULLIF(current_setting('app.firebase_uid', true), ''), '')
$$;

CREATE OR REPLACE FUNCTION app.email() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT LOWER(COALESCE(NULLIF(current_setting('app.email', true), ''), ''))
$$;

-- Role numbers mirror Api/Auth/RoleUtils.cs: 1 Admin, 2 Registrar, 3 Teacher,
-- 4 Program Head, 5 Student, 6 College Head. 0 means unauthenticated.

-- Accounting (7) is deliberately NOT here. is_staff() is the broad read grant -- study loads,
-- personal details, enrolment paperwork -- and the Accounting Office needs none of it. It gets
-- its own narrow policies instead, so the office that can withhold a grade cannot read one.
CREATE OR REPLACE FUNCTION app.is_staff() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT app.role() IN (1, 2, 3, 4, 6)
$$;

CREATE OR REPLACE FUNCTION app.is_accounting() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT app.role() = 7
$$;

-- Admin and Registrar are the roles the application already lets edit records freely.
CREATE OR REPLACE FUNCTION app.is_registrar() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT app.role() IN (1, 2)
$$;

CREATE OR REPLACE FUNCTION app.is_student() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT app.role() = 5
$$;

-- True when the signed-in student owns this UserID. Students are the only role scoped to
-- their own rows; every other role is scoped by the application layer, with these policies
-- as the backstop.
CREATE OR REPLACE FUNCTION app.owns(target uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT app.user_id() IS NOT NULL AND target = app.user_id()
$$;

-- A teacher may see a class they are assigned to. Program Heads are scoped per program in
-- the application layer; at this level they are treated as staff.
CREATE OR REPLACE FUNCTION app.teaches_class(target_class uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM "Classes" c
    WHERE c."ClassID" = target_class AND c."UserID" = app.user_id()
  )
$$;

-- The study load is the join between a student and a class, so most grade-shaped tables
-- reach their owner through it.
CREATE OR REPLACE FUNCTION app.studyload_owner(target_load uuid) RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT sl."UserID" FROM "StudyLoads" sl WHERE sl."StudyLoadID" = target_load
$$;

CREATE OR REPLACE FUNCTION app.studyload_class(target_load uuid) RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT sl."ClassID" FROM "StudyLoads" sl WHERE sl."StudyLoadID" = target_load
$$;

-- Enrollment paperwork hangs off an application, and the application is what names the
-- student. ReenrollmentService runs under the student's own session and reads all of this to
-- decide whether they may re-enrol, so these chains have to be walkable by that student --
-- otherwise the checks come back empty and the student looks eligible when they are not.

CREATE OR REPLACE FUNCTION app.owns_application(target_application uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM "EnrollmentApplications" ea
    WHERE ea."ApplicationID" = target_application AND ea."StudentUserID" = app.user_id()
  )
$$;

CREATE OR REPLACE FUNCTION app.owns_enrollment(target_enrollment uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM "EnrollmentForms" ef
    JOIN "EnrollmentApplications" ea ON ea."ApplicationID" = ef."ApplicationID"
    WHERE ef."EnrollmentID" = target_enrollment AND ea."StudentUserID" = app.user_id()
  )
$$;

CREATE OR REPLACE FUNCTION app.owns_response(target_response uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM "EnrollmentApplications" ea
    WHERE ea."ResponseID" = target_response AND ea."StudentUserID" = app.user_id()
  )
$$;
