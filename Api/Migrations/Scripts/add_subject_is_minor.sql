START TRANSACTION;
ALTER TABLE "Subjects" ADD "IsMinor" boolean NOT NULL DEFAULT FALSE;

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20261102141107_AddSubjectIsMinor', '10.0.12');

COMMIT;

