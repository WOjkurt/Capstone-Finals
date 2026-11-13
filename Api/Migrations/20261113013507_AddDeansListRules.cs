using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddDeansListRules : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<decimal>(
                name: "DeansListMaxGwa",
                table: "SchoolSettings",
                type: "numeric",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "DeansListWorstGrade",
                table: "SchoolSettings",
                type: "numeric",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DeansListMaxGwa",
                table: "SchoolSettings");

            migrationBuilder.DropColumn(
                name: "DeansListWorstGrade",
                table: "SchoolSettings");
        }
    }
}
