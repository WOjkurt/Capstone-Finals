START TRANSACTION;
CREATE TABLE "OverloadApprovals" (
    "OverloadApprovalID" uuid NOT NULL,
    "UserID" uuid NOT NULL,
    "TermID" uuid NOT NULL,
    "Units" numeric(5,1) NOT NULL,
    "MaxUnits" numeric(5,1) NOT NULL,
    "Reason" character varying(2000) NOT NULL,
    "ApprovedByUserID" uuid NOT NULL,
    "ApprovedAt" timestamp with time zone NOT NULL,
    CONSTRAINT "PK_OverloadApprovals" PRIMARY KEY ("OverloadApprovalID"),
    CONSTRAINT "FK_OverloadApprovals_AcademicTerms_TermID" FOREIGN KEY ("TermID") REFERENCES "AcademicTerms" ("TermID") ON DELETE RESTRICT,
    CONSTRAINT "FK_OverloadApprovals_Users_ApprovedByUserID" FOREIGN KEY ("ApprovedByUserID") REFERENCES "Users" ("UserID") ON DELETE RESTRICT,
    CONSTRAINT "FK_OverloadApprovals_Users_UserID" FOREIGN KEY ("UserID") REFERENCES "Users" ("UserID") ON DELETE RESTRICT
);

CREATE INDEX "IX_OverloadApprovals_ApprovedByUserID" ON "OverloadApprovals" ("ApprovedByUserID");

CREATE INDEX "IX_OverloadApprovals_TermID" ON "OverloadApprovals" ("TermID");

CREATE UNIQUE INDEX "UQ_OverloadApprovals_UserID_TermID" ON "OverloadApprovals" ("UserID", "TermID");

INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20261103101742_AddOverloadApprovals', '10.0.12');

COMMIT;


