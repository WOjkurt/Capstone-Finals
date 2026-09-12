using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddUniqueIndexContactsEnrollmentRelationType : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Contacts_EnrollmentID",
                table: "Contacts");

            migrationBuilder.CreateIndex(
                name: "UQ_Contacts_EnrollmentID_RelationType",
                table: "Contacts",
                columns: new[] { "EnrollmentID", "RelationType" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UQ_Contacts_EnrollmentID_RelationType",
                table: "Contacts");

            migrationBuilder.CreateIndex(
                name: "IX_Contacts_EnrollmentID",
                table: "Contacts",
                column: "EnrollmentID");
        }
    }
}
