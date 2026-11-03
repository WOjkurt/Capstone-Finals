START TRANSACTION;
CREATE TABLE "CreditedSubjects" (
    "CreditedSubjectID" uuid NOT NULL,
    "UserID" uuid NOT NULL,
    "SubjectID" uuid NOT NULL,
    "SourceSchool" character varying(200) NOT NULL,
    "SourceSubjectCode" character varying(50),
    "Grade" character varying(20),
    "SchoolYear" character varying(20),
    "RecordedByUserID" uuid NOT NULL,
    "RecordedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_CreditedSubjects" PRIMARY KEY ("CreditedSubjectID"),
    CONSTRAINT "FK_CreditedSubjects_Subjects_SubjectID" FOREIGN KEY ("SubjectID") REFERENCES "Subjects" ("SubjectID") ON DELETE RESTRICT,
    CONSTRAINT "FK_CreditedSubjects_Users_RecordedByUserID" FOREIGN KEY ("RecordedByUserID") REFERENCES "Users" ("UserID") ON DELETE RESTRICT,
    CONSTRAINT "FK_CreditedSubjects_Users_UserID" FOREIGN KEY ("UserID") REFERENCES "Users" ("UserID") ON DELETE RESTRICT
);

CREATE INDEX "IX_CreditedSubjects_RecordedByUserID" ON "CreditedSubjects" ("RecordedByUserID");

CREATE INDEX "IX_CreditedSubjects_SubjectID" ON "CreditedSubjects" ("SubjectID");

CREATE UNIQUE INDEX "UQ_CreditedSubjects_UserID_SubjectID" ON "CreditedSubjects" ("UserID", "SubjectID");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20261103114611_AddCreditedSubjects', '10.0.12');

COMMIT;


