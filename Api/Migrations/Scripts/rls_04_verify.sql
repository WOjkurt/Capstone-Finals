-- Row-level security, part 4: proof that the policies actually bite.
--
--   psql -U postgres -d dbtc_sis -f rls_04_verify.sql
--
-- Run as the postgres superuser, because it uses SET ROLE to borrow dbtc_api's view of the
-- data. Everything happens inside a transaction that ROLLBACKs, so it is safe to run against
-- a database with real records in it: it adds four users and two grades and then throws them
-- away. It prints nothing on success and raises on the first failed assertion.
--
-- Why this exists: RLS fails silently. Enable it on a table owned by the role you connect as
-- and every query still returns everything, with no error to notice. These assertions are the
-- difference between "we configured RLS" and "RLS is refusing the rows we think it is".

BEGIN;

\set s1 '5a1f0000-0000-4000-8000-000000000001'
\set s2 '5a1f0000-0000-4000-8000-000000000002'
\set tch '5a1f0000-0000-4000-8000-000000000003'
\set reg '5a1f0000-0000-4000-8000-000000000004'
\set acc '5a1f0000-0000-4000-8000-000000000007'
\set cls 'dddddddd-0000-0000-0000-00000000beef'
\set sl1 'eeeeeeee-0000-0000-0000-00000000bee1'
\set sl2 'eeeeeeee-0000-0000-0000-00000000bee2'
\set gr1 'ffffffff-0000-0000-0000-00000000bee1'
\set gr2 'ffffffff-0000-0000-0000-00000000bee2'

-- Fixtures go in as the superuser, which policies never apply to.
INSERT INTO "Users" ("UserID","FirebaseUID","Email","Role","CreatedAt","IsActive") VALUES
 (:'s1','rls-test-s1','rls-test-s1@dbtc-cebu.edu.ph',5,now(),true),
 (:'s2','rls-test-s2','rls-test-s2@dbtc-cebu.edu.ph',5,now(),true),
 (:'tch','rls-test-t','rls-test-t@dbtc-cebu.edu.ph',3,now(),true),
 (:'reg','rls-test-r','rls-test-r@dbtc-cebu.edu.ph',2,now(),true),
 (:'acc','rls-test-a','rls-test-a@dbtc-cebu.edu.ph',7,now(),true);

-- Reuse whatever subject/term already exist so this works on a populated database.
INSERT INTO "Classes" ("ClassID","SubjectID","UserID","TermID","ClassName","CreatedAt")
SELECT :'cls', (SELECT "SubjectID" FROM "Subjects" LIMIT 1), :'tch',
       (SELECT "TermID" FROM "AcademicTerms" LIMIT 1), 'RLS TEST', now();

INSERT INTO "StudyLoads" ("StudyLoadID","UserID","ClassID","LoadStatus","CreatedAt","IsForced") VALUES
 (:'sl1',:'s1',:'cls',2,now(),false),
 (:'sl2',:'s2',:'cls',2,now(),false);

INSERT INTO "Grades" ("GradeID","StudyLoadID","MidtermGrade","FinalGrade","SubmittedByUserID","DateSubmitted") VALUES
 (:'gr1',:'sl1',88,90,:'tch',now()),
 (:'gr2',:'sl2',75,77,:'tch',now());

-- A hold on student 1, to prove the student's own session can still see it.
INSERT INTO "EnrollmentHolds" ("HoldID","UserID","Reason","Note","AddedByUserID","AddedAt")
VALUES ('5a1f0000-0000-4000-8000-0000000000a1',:'s1',1,'rls test hold',:'reg',now());

CREATE OR REPLACE FUNCTION pg_temp.ctx(uid text, role text, fb text DEFAULT '', mail text DEFAULT '')
RETURNS void LANGUAGE sql AS $$
  SELECT set_config('app.user_id', uid, false),
         set_config('app.role', role, false),
         set_config('app.firebase_uid', fb, false),
         set_config('app.email', mail, false);
  SELECT NULL::void
$$;

CREATE OR REPLACE FUNCTION pg_temp.check(label text, got bigint, want bigint)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF got IS DISTINCT FROM want THEN
    RAISE EXCEPTION 'RLS FAILED: % -- expected %, got %', label, want, got;
  END IF;
END $$;

SET ROLE dbtc_api;   -- from here on, policies apply

DO $$
DECLARE n bigint;
BEGIN
  -- A student sees their own grade and no one else's.
  PERFORM pg_temp.ctx('5a1f0000-0000-4000-8000-000000000001','5','rls-test-s1');
  SELECT count(*) INTO n FROM "Grades"
   WHERE "GradeID" IN ('ffffffff-0000-0000-0000-00000000bee1','ffffffff-0000-0000-0000-00000000bee2');
  PERFORM pg_temp.check('student sees only own grade', n, 1);

  -- Naming another student's row by primary key changes nothing.
  SELECT count(*) INTO n FROM "Grades" WHERE "GradeID" = 'ffffffff-0000-0000-0000-00000000bee2';
  PERFORM pg_temp.check('student cannot read peer grade by id', n, 0);

  UPDATE "Grades" SET "FinalGrade" = 100 WHERE "GradeID" = 'ffffffff-0000-0000-0000-00000000bee2';
  GET DIAGNOSTICS n = ROW_COUNT;
  PERFORM pg_temp.check('student cannot update peer grade', n, 0);

  DELETE FROM "Grades" WHERE "GradeID" = 'ffffffff-0000-0000-0000-00000000bee2';
  GET DIAGNOSTICS n = ROW_COUNT;
  PERFORM pg_temp.check('student cannot delete peer grade', n, 0);

  -- The assigned teacher sees both; a teacher with no class sees neither.
  PERFORM pg_temp.ctx('5a1f0000-0000-4000-8000-000000000003','3','rls-test-t');
  SELECT count(*) INTO n FROM "Grades"
   WHERE "GradeID" IN ('ffffffff-0000-0000-0000-00000000bee1','ffffffff-0000-0000-0000-00000000bee2');
  PERFORM pg_temp.check('assigned teacher sees both grades', n, 2);

  PERFORM pg_temp.ctx('5a1f0000-0000-4000-8000-000000000009','3','rls-test-none');
  SELECT count(*) INTO n FROM "Grades"
   WHERE "GradeID" IN ('ffffffff-0000-0000-0000-00000000bee1','ffffffff-0000-0000-0000-00000000bee2');
  PERFORM pg_temp.check('unassigned teacher sees no grades', n, 0);

  -- Registrar keeps full reach.
  PERFORM pg_temp.ctx('5a1f0000-0000-4000-8000-000000000004','2','rls-test-r');
  SELECT count(*) INTO n FROM "Grades"
   WHERE "GradeID" IN ('ffffffff-0000-0000-0000-00000000bee1','ffffffff-0000-0000-0000-00000000bee2');
  PERFORM pg_temp.check('registrar sees both grades', n, 2);

  -- A request with no identity sees nothing at all: RLS fails closed.
  PERFORM pg_temp.ctx('','0');
  SELECT count(*) INTO n FROM "Grades";
  PERFORM pg_temp.check('anonymous sees no grades', n, 0);
  SELECT count(*) INTO n FROM "Users";
  PERFORM pg_temp.check('anonymous sees no users', n, 0);
  SELECT count(*) INTO n FROM "StudyLoads";
  PERFORM pg_temp.check('anonymous sees no study loads', n, 0);

  -- The sign-in bootstrap: FirebaseAuthMiddleware resolves a token into a Users row before
  -- any user_id exists, so the Users policy must accept a firebase_uid match on its own.
  PERFORM pg_temp.ctx('','0','rls-test-s1');
  SELECT count(*) INTO n FROM "Users" WHERE "FirebaseUID" = 'rls-test-s1';
  PERFORM pg_temp.check('sign-in can find its own user by firebase_uid', n, 1);

  -- And an imported student claiming a pending account matches on the verified email.
  PERFORM pg_temp.ctx('','0','rls-test-new','rls-test-s2@dbtc-cebu.edu.ph');
  SELECT count(*) INTO n FROM "Users" WHERE "Email" = 'rls-test-s2@dbtc-cebu.edu.ph';
  PERFORM pg_temp.check('pending account claimable by verified email', n, 1);

  -- A token for one account must not reach another.
  PERFORM pg_temp.ctx('','0','rls-test-s1');
  SELECT count(*) INTO n FROM "Users" WHERE "FirebaseUID" = 'rls-test-s2';
  PERFORM pg_temp.check('one token cannot read another account', n, 0);

  -- The Google Forms webhook: role -1, no user, must still read-for-duplicates and insert.
  PERFORM pg_temp.ctx('','-1');
  BEGIN
    INSERT INTO "EnrollmentResponses" ("ResponseID","Timestamp","EmailAddress","IsProcessed","Data")
    VALUES ('5a1f0000-0000-4000-8000-0000000000e1',now(),'rls-test-webhook@example.com',false,'{}'::jsonb);
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE EXCEPTION 'RLS FAILED: verified webhook cannot insert an enrollment response';
  END;
  SELECT count(*) INTO n FROM "EnrollmentResponses" WHERE "ResponseID" = '5a1f0000-0000-4000-8000-0000000000e1';
  PERFORM pg_temp.check('verified webhook can read back its own insert', n, 1);

  -- An anonymous caller that proved nothing still gets nothing.
  PERFORM pg_temp.ctx('','0');
  SELECT count(*) INTO n FROM "EnrollmentResponses";
  PERFORM pg_temp.check('anonymous sees no enrollment responses', n, 0);

  -- The fail-OPEN case, and the reason it is worth asserting. ReenrollmentService asks, under
  -- the student's own session, whether that student has a hold. If the policy hid the row the
  -- query would answer "no holds" and a held student would be allowed to re-enrol -- the
  -- failure that looks like success. A student must see their own hold, and only their own.
  PERFORM pg_temp.ctx('5a1f0000-0000-4000-8000-000000000001','5','rls-test-s1');
  SELECT count(*) INTO n FROM "EnrollmentHolds"
   WHERE "UserID" = '5a1f0000-0000-4000-8000-000000000001' AND "RemovedAt" IS NULL;
  PERFORM pg_temp.check('student sees their own enrollment hold', n, 1);

  PERFORM pg_temp.ctx('5a1f0000-0000-4000-8000-000000000002','5','rls-test-s2');
  SELECT count(*) INTO n FROM "EnrollmentHolds"
   WHERE "HoldID" = '5a1f0000-0000-4000-8000-0000000000a1';
  PERFORM pg_temp.check('student cannot see a peer hold', n, 0);

  -- Accounting (role 7). Its whole job is holds; the point of giving it its own policies
  -- rather than folding it into is_staff() is this pair of assertions.
  PERFORM pg_temp.ctx('5a1f0000-0000-4000-8000-000000000007','7','rls-test-a');

  SELECT count(*) INTO n FROM "EnrollmentHolds"
   WHERE "HoldID" = '5a1f0000-0000-4000-8000-0000000000a1';
  PERFORM pg_temp.check('accounting can read a hold', n, 1);

  SELECT count(*) INTO n FROM "Users" WHERE "FirebaseUID" = 'rls-test-s1';
  PERFORM pg_temp.check('accounting can find a student', n, 1);

  -- The one that matters: the office that can withhold a grade cannot read one.
  SELECT count(*) INTO n FROM "Grades"
   WHERE "GradeID" IN ('ffffffff-0000-0000-0000-00000000bee1','ffffffff-0000-0000-0000-00000000bee2');
  PERFORM pg_temp.check('accounting CANNOT read grades', n, 0);

  SELECT count(*) INTO n FROM "StudyLoads";
  PERFORM pg_temp.check('accounting cannot read study loads', n, 0);

  SELECT count(*) INTO n FROM "StudentPersonalDetails";
  PERFORM pg_temp.check('accounting cannot read personal details', n, 0);

  RAISE NOTICE 'RLS verification passed.';
END $$;

RESET ROLE;
ROLLBACK;
