using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddGradeReleaseAndSheetVerification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "VerifiedAt",
                table: "Classes",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "VerifiedByUserID",
                table: "Classes",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "GradesReleasedAt",
                table: "AcademicTerms",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "GradesReleasedByUserID",
                table: "AcademicTerms",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Classes_VerifiedByUserID",
                table: "Classes",
                column: "VerifiedByUserID");

            migrationBuilder.AddForeignKey(
                name: "FK_Classes_Users_VerifiedByUserID",
                table: "Classes",
                column: "VerifiedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.Restrict);

            // Every term that already exists is treated as released. Without this, the day this
            // ships every student loses sight of every grade until the Registrar works through
            // each term one at a time -- under pressure, and for no gain.
            migrationBuilder.Sql(
                @"UPDATE ""AcademicTerms"" SET ""GradesReleasedAt"" = NOW() WHERE ""GradesReleasedAt"" IS NULL;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Classes_Users_VerifiedByUserID",
                table: "Classes");

            migrationBuilder.DropIndex(
                name: "IX_Classes_VerifiedByUserID",
                table: "Classes");

            migrationBuilder.DropColumn(
                name: "VerifiedAt",
                table: "Classes");

            migrationBuilder.DropColumn(
                name: "VerifiedByUserID",
                table: "Classes");

            migrationBuilder.DropColumn(
                name: "GradesReleasedAt",
                table: "AcademicTerms");

            migrationBuilder.DropColumn(
                name: "GradesReleasedByUserID",
                table: "AcademicTerms");
        }
    }
}
