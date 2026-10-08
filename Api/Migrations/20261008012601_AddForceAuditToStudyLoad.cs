using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddForceAuditToStudyLoad : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "ForcedByUserID",
                table: "StudyLoads",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ForcedReason",
                table: "StudyLoads",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsForced",
                table: "StudyLoads",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_StudyLoads_ForcedByUserID",
                table: "StudyLoads",
                column: "ForcedByUserID");

            migrationBuilder.AddForeignKey(
                name: "FK_StudyLoads_Users_ForcedByUserID",
                table: "StudyLoads",
                column: "ForcedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_StudyLoads_Users_ForcedByUserID",
                table: "StudyLoads");

            migrationBuilder.DropIndex(
                name: "IX_StudyLoads_ForcedByUserID",
                table: "StudyLoads");

            migrationBuilder.DropColumn(
                name: "ForcedByUserID",
                table: "StudyLoads");

            migrationBuilder.DropColumn(
                name: "ForcedReason",
                table: "StudyLoads");

            migrationBuilder.DropColumn(
                name: "IsForced",
                table: "StudyLoads");
        }
    }
}
