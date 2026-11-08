using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddTermEnrollmentPeriod : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateOnly>(
                name: "EnrollmentClosesOn",
                table: "AcademicTerms",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "EnrollmentOpensOn",
                table: "AcademicTerms",
                type: "date",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "EnrollmentClosesOn",
                table: "AcademicTerms");

            migrationBuilder.DropColumn(
                name: "EnrollmentOpensOn",
                table: "AcademicTerms");
        }
    }
}
