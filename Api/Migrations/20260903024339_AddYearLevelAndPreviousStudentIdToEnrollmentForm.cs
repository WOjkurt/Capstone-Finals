using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddYearLevelAndPreviousStudentIdToEnrollmentForm : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "PreviousStudentID",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "YearLevel",
                table: "EnrollmentForms",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "PreviousStudentID",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "YearLevel",
                table: "EnrollmentForms");
        }
    }
}
