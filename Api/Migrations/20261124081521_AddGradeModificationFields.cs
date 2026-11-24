using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddGradeModificationFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "ModificationReason",
                table: "Grades",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ModifiedAt",
                table: "Grades",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "ModifiedByUserID",
                table: "Grades",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Grades_ModifiedByUserID",
                table: "Grades",
                column: "ModifiedByUserID");

            migrationBuilder.AddForeignKey(
                name: "FK_Grades_Users_ModifiedByUserID",
                table: "Grades",
                column: "ModifiedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Grades_Users_ModifiedByUserID",
                table: "Grades");

            migrationBuilder.DropIndex(
                name: "IX_Grades_ModifiedByUserID",
                table: "Grades");

            migrationBuilder.DropColumn(
                name: "ModificationReason",
                table: "Grades");

            migrationBuilder.DropColumn(
                name: "ModifiedAt",
                table: "Grades");

            migrationBuilder.DropColumn(
                name: "ModifiedByUserID",
                table: "Grades");
        }
    }
}
