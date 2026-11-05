using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCreditUnitsAndCrossEnrollment : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "CreditedUnits",
                table: "CreditedSubjects",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "Kind",
                table: "CreditedSubjects",
                type: "integer",
                nullable: false,
                defaultValue: 1);

            // Credits recorded before this change were for the subject's full units.
            migrationBuilder.Sql(
                "UPDATE \"CreditedSubjects\" c SET \"CreditedUnits\" = s.\"LecUnits\" + s.\"LabUnits\" " +
                "FROM \"Subjects\" s WHERE s.\"SubjectID\" = c.\"SubjectID\";");

            migrationBuilder.AddColumn<Guid>(
                name: "TermID",
                table: "CreditedSubjects",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_CreditedSubjects_TermID",
                table: "CreditedSubjects",
                column: "TermID");

            migrationBuilder.AddForeignKey(
                name: "FK_CreditedSubjects_AcademicTerms_TermID",
                table: "CreditedSubjects",
                column: "TermID",
                principalTable: "AcademicTerms",
                principalColumn: "TermID");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_CreditedSubjects_AcademicTerms_TermID",
                table: "CreditedSubjects");

            migrationBuilder.DropIndex(
                name: "IX_CreditedSubjects_TermID",
                table: "CreditedSubjects");

            migrationBuilder.DropColumn(
                name: "CreditedUnits",
                table: "CreditedSubjects");

            migrationBuilder.DropColumn(
                name: "Kind",
                table: "CreditedSubjects");

            migrationBuilder.DropColumn(
                name: "TermID",
                table: "CreditedSubjects");
        }
    }
}
