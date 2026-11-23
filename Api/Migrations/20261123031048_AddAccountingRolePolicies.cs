using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <summary>
    /// Row-level security for the Accounting Office (role 7).
    ///
    /// Accounting is NOT added to app.is_staff(). That function is the broad read grant --
    /// study loads, personal details, enrolment paperwork -- and the Accounting Office needs
    /// none of it. It gets three things instead: read Users and UserDetails so a student can be
    /// found and named, and read/write EnrollmentHolds. So the office that can withhold a
    /// grade cannot read one, and rls_04_verify.sql asserts exactly that.
    ///
    /// This re-runs the whole of rls_01 and rls_02 rather than shipping a delta. Both are
    /// written to be re-runnable (CREATE OR REPLACE, DROP POLICY IF EXISTS), and replaying
    /// them converges a database whose policies were applied by hand -- which is how the
    /// first rollout actually went -- onto the same state as one built purely by migrations.
    /// </summary>
    public partial class AddAccountingRolePolicies : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.Sql(Foundation);
            migrationBuilder.Sql(Policies);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Narrowing back is a policy change, not a schema one: drop Accounting's reach by
            // re-running the previous migration's SQL, which this deliberately does not undo.
        }

        private const string Foundation = """
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
""";

        private const string Policies = """
-- Row-level security, part 2: one policy set per table.
--
-- Shape of every table below:
--   * staff (roles 1,2,3,4,6) read what the application already lets them read;
--   * a student (role 5) reaches only rows that trace back to their own UserID;
--   * role 0 -- unauthenticated, or a request that slipped past the auth middleware --
--     matches nothing and therefore sees nothing.
--
-- Writes are deliberately narrower than reads. The application decides who may write; these
-- policies only stop a write aimed at someone else's row.

-- Accounting (role 7) is granted exactly three things below: read Users and UserDetails so a
-- student can be found and named, and read/write EnrollmentHolds. Everything else -- grades,
-- study loads, personal details, enrolment paperwork -- is left out, so a compromised or
-- mistaken Accounting account cannot read a single grade.

-- ── Reference data ────────────────────────────────────────────────────────────
-- School-wide and not sensitive: any signed-in user reads, only Admin/Registrar writes.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'AcademicPrograms','AcademicTerms','Subjects','Curricula',
    'SubjectPrerequisites','AccreditedSchools','Positions','SchoolSettings'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', t || '_read', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', t || '_write', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR SELECT USING (app.role() <> 0)', t || '_read', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (app.is_registrar()) WITH CHECK (app.is_registrar())',
      t || '_write', t);
  END LOOP;
END $$;

-- ── Classes and schedules ─────────────────────────────────────────────────────
-- A student sees a class they are enrolled in; a teacher sees one they are assigned to.
ALTER TABLE "Classes" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Classes_read" ON "Classes";
CREATE POLICY "Classes_read" ON "Classes" FOR SELECT USING (
  app.is_staff()
  OR (app.is_student() AND EXISTS (
        SELECT 1 FROM "StudyLoads" sl
        WHERE sl."ClassID" = "Classes"."ClassID" AND sl."UserID" = app.user_id()))
);
DROP POLICY IF EXISTS "Classes_write" ON "Classes";
CREATE POLICY "Classes_write" ON "Classes" FOR ALL
  USING (app.is_registrar()) WITH CHECK (app.is_registrar());

ALTER TABLE "ClassSchedules" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ClassSchedules_read" ON "ClassSchedules";
CREATE POLICY "ClassSchedules_read" ON "ClassSchedules" FOR SELECT USING (
  app.is_staff()
  OR (app.is_student() AND EXISTS (
        SELECT 1 FROM "StudyLoads" sl
        WHERE sl."ClassID" = "ClassSchedules"."ClassID" AND sl."UserID" = app.user_id()))
);
DROP POLICY IF EXISTS "ClassSchedules_write" ON "ClassSchedules";
CREATE POLICY "ClassSchedules_write" ON "ClassSchedules" FOR ALL
  USING (app.is_registrar()) WITH CHECK (app.is_registrar());

-- ── Study loads ───────────────────────────────────────────────────────────────
ALTER TABLE "StudyLoads" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "StudyLoads_read" ON "StudyLoads";
CREATE POLICY "StudyLoads_read" ON "StudyLoads" FOR SELECT USING (
  app.is_staff() OR app.owns("UserID")
);
DROP POLICY IF EXISTS "StudyLoads_write" ON "StudyLoads";
CREATE POLICY "StudyLoads_write" ON "StudyLoads" FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());

-- ── Grades ────────────────────────────────────────────────────────────────────
-- The table a leak would hurt most. A student reaches a grade only through their own study
-- load; a teacher only through a class they are assigned to.
ALTER TABLE "Grades" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Grades_read" ON "Grades";
CREATE POLICY "Grades_read" ON "Grades" FOR SELECT USING (
  app.is_registrar()
  OR app.role() IN (4, 6)
  OR (app.is_student() AND app.owns(app.studyload_owner("StudyLoadID")))
  OR (app.role() = 3 AND app.teaches_class(app.studyload_class("StudyLoadID")))
);
DROP POLICY IF EXISTS "Grades_write" ON "Grades";
CREATE POLICY "Grades_write" ON "Grades" FOR ALL USING (
  app.is_registrar() OR (app.role() = 3 AND app.teaches_class(app.studyload_class("StudyLoadID")))
) WITH CHECK (
  app.is_registrar() OR (app.role() = 3 AND app.teaches_class(app.studyload_class("StudyLoadID")))
);

ALTER TABLE "GradeClearances" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "GradeClearances_read" ON "GradeClearances";
CREATE POLICY "GradeClearances_read" ON "GradeClearances" FOR SELECT USING (
  app.is_staff() OR app.owns("UserID")
);
DROP POLICY IF EXISTS "GradeClearances_write" ON "GradeClearances";
CREATE POLICY "GradeClearances_write" ON "GradeClearances" FOR ALL
  USING (app.is_registrar()) WITH CHECK (app.is_registrar());

ALTER TABLE "GradeCorrections" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "GradeCorrections_read" ON "GradeCorrections";
CREATE POLICY "GradeCorrections_read" ON "GradeCorrections" FOR SELECT USING (
  app.is_staff() OR app.owns("RequestedByUserID")
);
DROP POLICY IF EXISTS "GradeCorrections_write" ON "GradeCorrections";
CREATE POLICY "GradeCorrections_write" ON "GradeCorrections" FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());

-- ── Student records ───────────────────────────────────────────────────────────
ALTER TABLE "StudentPersonalDetails" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "StudentPersonalDetails_read" ON "StudentPersonalDetails";
CREATE POLICY "StudentPersonalDetails_read" ON "StudentPersonalDetails" FOR SELECT USING (
  app.is_staff() OR app.owns("UserID")
);
DROP POLICY IF EXISTS "StudentPersonalDetails_write" ON "StudentPersonalDetails";
CREATE POLICY "StudentPersonalDetails_write" ON "StudentPersonalDetails" FOR ALL
  USING (app.is_staff() OR app.owns("UserID"))
  WITH CHECK (app.is_staff() OR app.owns("UserID"));

ALTER TABLE "CreditedSubjects" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "CreditedSubjects_read" ON "CreditedSubjects";
CREATE POLICY "CreditedSubjects_read" ON "CreditedSubjects" FOR SELECT USING (
  app.is_staff() OR app.owns("UserID")
);
DROP POLICY IF EXISTS "CreditedSubjects_write" ON "CreditedSubjects";
CREATE POLICY "CreditedSubjects_write" ON "CreditedSubjects" FOR ALL
  USING (app.is_registrar()) WITH CHECK (app.is_registrar());

-- ── Staff-only tables ─────────────────────────────────────────────────────────
-- Nothing here is a student's to see, including holds and overload approvals about them:
-- the application surfaces those as a refusal, never as a row.
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'OverloadApprovals','StudyLoadChanges'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I', t || '_staff', t);
    EXECUTE format(
      'CREATE POLICY %I ON %I FOR ALL USING (app.is_staff()) WITH CHECK (app.is_staff())',
      t || '_staff', t);
  END LOOP;
END $$;


-- A student reads their own enrolment paperwork; only staff may change it.
-- EnrollmentHolds is the one that matters most: ReenrollmentService asks, under the
-- student's own session, whether that student is on hold. A staff-only policy would answer
-- "no holds" for every student and let a held student straight through -- a policy that
-- fails OPEN, which is worse than one that fails closed.
ALTER TABLE "EnrollmentHolds" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "EnrollmentHolds_staff" ON "EnrollmentHolds";
DROP POLICY IF EXISTS "EnrollmentHolds_read" ON "EnrollmentHolds";
CREATE POLICY "EnrollmentHolds_read" ON "EnrollmentHolds" FOR SELECT
  USING (app.is_staff() OR app.is_accounting() OR app.owns("UserID"));
DROP POLICY IF EXISTS "EnrollmentHolds_write" ON "EnrollmentHolds";
-- Accounting writes holds; the service, not this policy, confines it to the UnpaidBalance
-- reason. A policy can gate the row, not the column value the caller is about to supply.
CREATE POLICY "EnrollmentHolds_write" ON "EnrollmentHolds" FOR ALL
  USING (app.is_staff() OR app.is_accounting())
  WITH CHECK (app.is_staff() OR app.is_accounting());

ALTER TABLE "EnrollmentForms" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "EnrollmentForms_staff" ON "EnrollmentForms";
DROP POLICY IF EXISTS "EnrollmentForms_read" ON "EnrollmentForms";
CREATE POLICY "EnrollmentForms_read" ON "EnrollmentForms" FOR SELECT
  USING (app.is_staff() OR app.owns_application("ApplicationID"));
DROP POLICY IF EXISTS "EnrollmentForms_write" ON "EnrollmentForms";
CREATE POLICY "EnrollmentForms_write" ON "EnrollmentForms" FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());

ALTER TABLE "Contacts" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Contacts_staff" ON "Contacts";
DROP POLICY IF EXISTS "Contacts_read" ON "Contacts";
CREATE POLICY "Contacts_read" ON "Contacts" FOR SELECT
  USING (app.is_staff() OR app.owns_enrollment("EnrollmentID"));
DROP POLICY IF EXISTS "Contacts_write" ON "Contacts";
CREATE POLICY "Contacts_write" ON "Contacts" FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());

-- The Google Forms webhook is the one caller with no signed-in user that still has to write.
-- It arrives as role -1, set by RequireWebhookSecretAttribute only after the HMAC signature
-- checks out, and it needs SELECT as well as INSERT because it looks for a duplicate
-- submission first. Role 0 -- an anonymous caller that proved nothing -- still gets nothing.
ALTER TABLE "EnrollmentResponses" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "EnrollmentResponses_staff" ON "EnrollmentResponses";
DROP POLICY IF EXISTS "EnrollmentResponses_read" ON "EnrollmentResponses";
CREATE POLICY "EnrollmentResponses_read" ON "EnrollmentResponses" FOR SELECT
  USING (app.is_staff() OR app.role() = -1 OR app.owns_response("ResponseID"));
DROP POLICY IF EXISTS "EnrollmentResponses_webhook_insert" ON "EnrollmentResponses";
CREATE POLICY "EnrollmentResponses_webhook_insert" ON "EnrollmentResponses" FOR INSERT
  WITH CHECK (app.is_staff() OR app.role() = -1);
DROP POLICY IF EXISTS "EnrollmentResponses_staff_write" ON "EnrollmentResponses";
CREATE POLICY "EnrollmentResponses_staff_write" ON "EnrollmentResponses" FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());


-- An applicant needs to see the application that became their own account.
ALTER TABLE "EnrollmentApplications" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "EnrollmentApplications_read" ON "EnrollmentApplications";
CREATE POLICY "EnrollmentApplications_read" ON "EnrollmentApplications" FOR SELECT USING (
  app.is_staff() OR app.owns("StudentUserID")
);
DROP POLICY IF EXISTS "EnrollmentApplications_write" ON "EnrollmentApplications";
CREATE POLICY "EnrollmentApplications_write" ON "EnrollmentApplications" FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());

-- ── Audit log ─────────────────────────────────────────────────────────────────
-- Append-only, and the INSERT policy is unconditional on purpose: a sign-in that is being
-- REFUSED still has to be recorded, and at that moment the session has no user at all.
-- Reading stays with Admin and Registrar.
ALTER TABLE "ActivityLogs" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "ActivityLogs_read" ON "ActivityLogs";
CREATE POLICY "ActivityLogs_read" ON "ActivityLogs" FOR SELECT USING (app.is_registrar());
DROP POLICY IF EXISTS "ActivityLogs_append" ON "ActivityLogs";
CREATE POLICY "ActivityLogs_append" ON "ActivityLogs" FOR INSERT WITH CHECK (true);

-- ── Identity ──────────────────────────────────────────────────────────────────
-- The bootstrap case. FirebaseAuthMiddleware turns a verified token into a Users row, and
-- that lookup runs before any UserID is known -- so the policy also accepts a match on the
-- firebase_uid from the token, or, for an imported student claiming a pending account, on
-- the verified email. Both values come from a token Firebase already validated.
ALTER TABLE "Users" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users_read" ON "Users";
CREATE POLICY "Users_read" ON "Users" FOR SELECT USING (
  app.is_staff()
  OR app.is_accounting()
  OR app.owns("UserID")
  OR (app.firebase_uid() <> '' AND "FirebaseUID" = app.firebase_uid())
  OR (app.email() <> '' AND LOWER("Email") = app.email())
);
DROP POLICY IF EXISTS "Users_write" ON "Users";
CREATE POLICY "Users_write" ON "Users" FOR ALL USING (
  app.is_registrar()
  OR app.owns("UserID")
  OR (app.firebase_uid() <> '' AND "FirebaseUID" = app.firebase_uid())
  OR (app.email() <> '' AND LOWER("Email") = app.email())
) WITH CHECK (
  app.is_registrar()
  OR app.owns("UserID")
  OR (app.firebase_uid() <> '' AND "FirebaseUID" = app.firebase_uid())
  OR (app.email() <> '' AND LOWER("Email") = app.email())
);

ALTER TABLE "UserDetails" ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "UserDetails_read" ON "UserDetails";
CREATE POLICY "UserDetails_read" ON "UserDetails" FOR SELECT USING (
  app.is_staff()
  OR app.is_accounting()
  OR app.owns("UserID")
  OR EXISTS (SELECT 1 FROM "Users" u
             WHERE u."UserID" = "UserDetails"."UserID"
               AND app.firebase_uid() <> '' AND u."FirebaseUID" = app.firebase_uid())
);
DROP POLICY IF EXISTS "UserDetails_write" ON "UserDetails";
CREATE POLICY "UserDetails_write" ON "UserDetails" FOR ALL
  USING (app.is_staff()) WITH CHECK (app.is_staff());
""";
    }
}
