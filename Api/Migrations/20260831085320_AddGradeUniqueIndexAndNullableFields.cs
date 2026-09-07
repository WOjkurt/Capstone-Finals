using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddGradeUniqueIndexAndNullableFields : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_GradeCorrections_Users_ReviewedByUserID",
                table: "GradeCorrections");

            migrationBuilder.DropIndex(
                name: "IX_Grades_StudyLoadID",
                table: "Grades");

            migrationBuilder.AlterColumn<int>(
                name: "Remarks",
                table: "Grades",
                type: "integer",
                nullable: true,
                oldClrType: typeof(int),
                oldType: "integer");

            migrationBuilder.AlterColumn<decimal>(
                name: "MidtermGrade",
                table: "Grades",
                type: "numeric",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric");

            migrationBuilder.AlterColumn<decimal>(
                name: "FinalGrade",
                table: "Grades",
                type: "numeric",
                nullable: true,
                oldClrType: typeof(decimal),
                oldType: "numeric");

            migrationBuilder.AlterColumn<Guid>(
                name: "ReviewedByUserID",
                table: "GradeCorrections",
                type: "uuid",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AlterColumn<DateTime>(
                name: "DateReviewed",
                table: "GradeCorrections",
                type: "timestamp with time zone",
                nullable: true,
                oldClrType: typeof(DateTime),
                oldType: "timestamp with time zone");

            migrationBuilder.CreateIndex(
                name: "UQ_Grades_StudyLoadID",
                table: "Grades",
                column: "StudyLoadID",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_GradeCorrections_Users_ReviewedByUserID",
                table: "GradeCorrections",
                column: "ReviewedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_GradeCorrections_Users_ReviewedByUserID",
                table: "GradeCorrections");

            migrationBuilder.DropIndex(
                name: "UQ_Grades_StudyLoadID",
                table: "Grades");

            migrationBuilder.AlterColumn<int>(
                name: "Remarks",
                table: "Grades",
                type: "integer",
                nullable: false,
                defaultValue: 0,
                oldClrType: typeof(int),
                oldType: "integer",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "MidtermGrade",
                table: "Grades",
                type: "numeric",
                nullable: false,
                defaultValue: 0m,
                oldClrType: typeof(decimal),
                oldType: "numeric",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "FinalGrade",
                table: "Grades",
                type: "numeric",
                nullable: false,
                defaultValue: 0m,
                oldClrType: typeof(decimal),
                oldType: "numeric",
                oldNullable: true);

            migrationBuilder.AlterColumn<Guid>(
                name: "ReviewedByUserID",
                table: "GradeCorrections",
                type: "uuid",
                nullable: false,
                defaultValue: new Guid("00000000-0000-0000-0000-000000000000"),
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<DateTime>(
                name: "DateReviewed",
                table: "GradeCorrections",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified),
                oldClrType: typeof(DateTime),
                oldType: "timestamp with time zone",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Grades_StudyLoadID",
                table: "Grades",
                column: "StudyLoadID");

            migrationBuilder.AddForeignKey(
                name: "FK_GradeCorrections_Users_ReviewedByUserID",
                table: "GradeCorrections",
                column: "ReviewedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
