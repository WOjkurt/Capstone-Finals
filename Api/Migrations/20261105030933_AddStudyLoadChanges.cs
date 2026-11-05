using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddStudyLoadChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "StudyLoadChanges",
                columns: table => new
                {
                    ChangeID = table.Column<Guid>(type: "uuid", nullable: false),
                    StudyLoadID = table.Column<Guid>(type: "uuid", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    TermID = table.Column<Guid>(type: "uuid", nullable: false),
                    Kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ChangedByUserID = table.Column<Guid>(type: "uuid", nullable: true),
                    ChangedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StudyLoadChanges", x => x.ChangeID);
                    table.ForeignKey(
                        name: "FK_StudyLoadChanges_StudyLoads_StudyLoadID",
                        column: x => x.StudyLoadID,
                        principalTable: "StudyLoads",
                        principalColumn: "StudyLoadID",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StudyLoadChanges_StudyLoadID",
                table: "StudyLoadChanges",
                column: "StudyLoadID");

            migrationBuilder.CreateIndex(
                name: "IX_StudyLoadChanges_UserID_TermID",
                table: "StudyLoadChanges",
                columns: new[] { "UserID", "TermID" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "StudyLoadChanges");
        }
    }
}
