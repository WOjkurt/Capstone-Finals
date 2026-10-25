START TRANSACTION;
ALTER TABLE "EnrollmentApplications" ADD "SchoolEmail" text;

CREATE UNIQUE INDEX "UQ_EnrollmentApplications_SchoolEmail" ON "EnrollmentApplications" ("SchoolEmail") WHERE "SchoolEmail" IS NOT NULL;

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20261025130706_AddSchoolEmailToEnrollmentApplication', '10.0.12');

COMMIT;

