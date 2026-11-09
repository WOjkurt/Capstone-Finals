using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddStudentId : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "StudentID",
                table: "UserDetails",
                type: "character varying(20)",
                maxLength: 20,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "UQ_UserDetails_StudentID",
                table: "UserDetails",
                column: "StudentID",
                unique: true,
                filter: "\"StudentID\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UQ_UserDetails_StudentID",
                table: "UserDetails");

            migrationBuilder.DropColumn(
                name: "StudentID",
                table: "UserDetails");
        }
    }
}
