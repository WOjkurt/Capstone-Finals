using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddGradeClearances : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GradeClearances",
                columns: table => new
                {
                    ClearanceID = table.Column<Guid>(type: "uuid", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    TermID = table.Column<Guid>(type: "uuid", nullable: false),
                    IsCleared = table.Column<bool>(type: "boolean", nullable: false),
                    ClearedByUserID = table.Column<Guid>(type: "uuid", nullable: true),
                    ClearedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GradeClearances", x => x.ClearanceID);
                    table.ForeignKey(
                        name: "FK_GradeClearances_AcademicTerms_TermID",
                        column: x => x.TermID,
                        principalTable: "AcademicTerms",
                        principalColumn: "TermID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GradeClearances_Users_ClearedByUserID",
                        column: x => x.ClearedByUserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_GradeClearances_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_GradeClearances_ClearedByUserID",
                table: "GradeClearances",
                column: "ClearedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_GradeClearances_TermID",
                table: "GradeClearances",
                column: "TermID");

            migrationBuilder.CreateIndex(
                name: "UQ_GradeClearances_UserID_TermID",
                table: "GradeClearances",
                columns: new[] { "UserID", "TermID" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GradeClearances");
        }
    }
}
