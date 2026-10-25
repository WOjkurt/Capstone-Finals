using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSchoolEmailToEnrollmentApplication : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SchoolEmail",
                table: "EnrollmentApplications",
                type: "text",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "UQ_EnrollmentApplications_SchoolEmail",
                table: "EnrollmentApplications",
                column: "SchoolEmail",
                unique: true,
                filter: "\"SchoolEmail\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UQ_EnrollmentApplications_SchoolEmail",
                table: "EnrollmentApplications");

            migrationBuilder.DropColumn(
                name: "SchoolEmail",
                table: "EnrollmentApplications");
        }
    }
}
