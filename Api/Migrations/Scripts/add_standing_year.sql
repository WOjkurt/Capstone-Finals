START TRANSACTION;
DROP INDEX "IX_Subjects_ProgramID";

ALTER TABLE "Subjects" ADD "StandingYear" integer;

CREATE UNIQUE INDEX "UQ_Subjects_ProgramID_SubjectCode" ON "Subjects" ("ProgramID", "SubjectCode");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20261020022622_AddSubjectStandingYearAndUniqueCode', '10.0.12');

COMMIT;

