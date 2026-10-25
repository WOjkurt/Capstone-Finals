using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddSubjectStandingYearAndUniqueCode : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Subjects_ProgramID",
                table: "Subjects");

            migrationBuilder.AddColumn<int>(
                name: "StandingYear",
                table: "Subjects",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "UQ_Subjects_ProgramID_SubjectCode",
                table: "Subjects",
                columns: new[] { "ProgramID", "SubjectCode" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "UQ_Subjects_ProgramID_SubjectCode",
                table: "Subjects");

            migrationBuilder.DropColumn(
                name: "StandingYear",
                table: "Subjects");

            migrationBuilder.CreateIndex(
                name: "IX_Subjects_ProgramID",
                table: "Subjects",
                column: "ProgramID");
        }
    }
}
