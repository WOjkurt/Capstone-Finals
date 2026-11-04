START TRANSACTION;
CREATE TABLE "ActivityLogs" (
    "ActivityLogID" uuid NOT NULL,
    "OccurredAt" timestamp with time zone NOT NULL,
    "ActorUserID" uuid,
    "ActorName" character varying(200) NOT NULL,
    "ActorRole" integer,
    "Action" character varying(50) NOT NULL,
    "StudentUserID" uuid,
    "StudentName" character varying(200),
    "TermID" uuid,
    "Summary" character varying(1000) NOT NULL,
    CONSTRAINT "PK_ActivityLogs" PRIMARY KEY ("ActivityLogID")
);

CREATE INDEX "IX_ActivityLogs_Action" ON "ActivityLogs" ("Action");

CREATE INDEX "IX_ActivityLogs_OccurredAt" ON "ActivityLogs" ("OccurredAt");

CREATE INDEX "IX_ActivityLogs_StudentUserID" ON "ActivityLogs" ("StudentUserID");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20261104010932_AddActivityLogs', '10.0.12');

COMMIT;


