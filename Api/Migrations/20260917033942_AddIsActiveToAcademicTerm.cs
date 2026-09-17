using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddIsActiveToAcademicTerm : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsActive",
                table: "AcademicTerms",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.Sql(@"
                UPDATE ""AcademicTerms""
                SET ""IsActive"" = TRUE
                WHERE ""TermID"" = (
                    SELECT ""TermID"" FROM ""AcademicTerms""
                    ORDER BY ""SchoolYear"" DESC, ""Semester"" DESC
                    LIMIT 1
                );
            ");

            migrationBuilder.CreateIndex(
                name: "idx_academic_terms_single_active",
                table: "AcademicTerms",
                column: "IsActive",
                unique: true,
                filter: "\"IsActive\" = TRUE");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "idx_academic_terms_single_active",
                table: "AcademicTerms");

            migrationBuilder.DropColumn(
                name: "IsActive",
                table: "AcademicTerms");
        }
    }
}
