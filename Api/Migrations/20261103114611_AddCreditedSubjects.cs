using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCreditedSubjects : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "CreditedSubjects",
                columns: table => new
                {
                    CreditedSubjectID = table.Column<Guid>(type: "uuid", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    SubjectID = table.Column<Guid>(type: "uuid", nullable: false),
                    SourceSchool = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    SourceSubjectCode = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Grade = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    SchoolYear = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    RecordedByUserID = table.Column<Guid>(type: "uuid", nullable: false),
                    RecordedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CreditedSubjects", x => x.CreditedSubjectID);
                    table.ForeignKey(
                        name: "FK_CreditedSubjects_Subjects_SubjectID",
                        column: x => x.SubjectID,
                        principalTable: "Subjects",
                        principalColumn: "SubjectID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CreditedSubjects_Users_RecordedByUserID",
                        column: x => x.RecordedByUserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CreditedSubjects_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_CreditedSubjects_RecordedByUserID",
                table: "CreditedSubjects",
                column: "RecordedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_CreditedSubjects_SubjectID",
                table: "CreditedSubjects",
                column: "SubjectID");

            migrationBuilder.CreateIndex(
                name: "UQ_CreditedSubjects_UserID_SubjectID",
                table: "CreditedSubjects",
                columns: new[] { "UserID", "SubjectID" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "CreditedSubjects");
        }
    }
}
