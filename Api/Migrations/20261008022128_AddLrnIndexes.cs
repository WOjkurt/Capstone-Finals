using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddLrnIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "UQ_UserDetails_LRN",
                table: "UserDetails",
                column: "LRN",
                unique: true,
                filter: "\"LRN\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentForms_LRN",
                table: "EnrollmentForms",
                column: "LRN");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UQ_UserDetails_LRN",
                table: "UserDetails");

            migrationBuilder.DropIndex(
                name: "IX_EnrollmentForms_LRN",
                table: "EnrollmentForms");
        }
    }
}
