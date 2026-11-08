using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddReturningApplications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_EnrollmentApplications_StudentUserID",
                table: "EnrollmentApplications");

            migrationBuilder.AddColumn<string>(
                name: "ChangedFields",
                table: "EnrollmentApplications",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsReturning",
                table: "EnrollmentApplications",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "UQ_EnrollmentApplications_Student_Term",
                table: "EnrollmentApplications",
                columns: new[] { "StudentUserID", "TermID" },
                unique: true,
                filter: "\"StudentUserID\" IS NOT NULL AND \"Status\" <> 3");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UQ_EnrollmentApplications_Student_Term",
                table: "EnrollmentApplications");

            migrationBuilder.DropColumn(
                name: "ChangedFields",
                table: "EnrollmentApplications");

            migrationBuilder.DropColumn(
                name: "IsReturning",
                table: "EnrollmentApplications");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentApplications_StudentUserID",
                table: "EnrollmentApplications",
                column: "StudentUserID");
        }
    }
}
