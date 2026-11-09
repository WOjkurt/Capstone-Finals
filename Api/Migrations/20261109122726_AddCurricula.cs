using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddCurricula : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Curricula",
                columns: table => new
                {
                    CurriculumID = table.Column<Guid>(type: "uuid", nullable: false),
                    ProgramID = table.Column<int>(type: "integer", nullable: false),
                    Name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    EffectiveFromYear = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Curricula", x => x.CurriculumID);
                    table.ForeignKey(
                        name: "FK_Curricula_AcademicPrograms_ProgramID",
                        column: x => x.ProgramID,
                        principalTable: "AcademicPrograms",
                        principalColumn: "ProgramID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.AddColumn<Guid>(
                name: "CurriculumID",
                table: "Subjects",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "CurriculumID",
                table: "UserDetails",
                type: "uuid",
                nullable: true);

            // Every program gets a first curriculum holding all of its current subjects, and every student
            // of the program follows it. The Registrar renames it and adds newer curricula afterwards.
            migrationBuilder.Sql(@"
INSERT INTO ""Curricula"" (""CurriculumID"", ""ProgramID"", ""Name"", ""EffectiveFromYear"", ""CreatedAt"")
SELECT gen_random_uuid(), p.""ProgramID"", 'First curriculum', 2000, now()
FROM ""AcademicPrograms"" p
WHERE NOT EXISTS (SELECT 1 FROM ""Curricula"" c WHERE c.""ProgramID"" = p.""ProgramID"");

UPDATE ""Subjects"" s SET ""CurriculumID"" = c.""CurriculumID""
FROM ""Curricula"" c
WHERE c.""ProgramID"" = s.""ProgramID"" AND s.""CurriculumID"" IS NULL;

UPDATE ""UserDetails"" ud SET ""CurriculumID"" = c.""CurriculumID""
FROM ""Curricula"" c, ""Users"" u
WHERE c.""ProgramID"" = ud.""ProgramID"" AND u.""UserID"" = ud.""UserID"" AND u.""Role"" = 5 AND ud.""CurriculumID"" IS NULL;
");

            migrationBuilder.AlterColumn<Guid>(
                name: "CurriculumID",
                table: "Subjects",
                type: "uuid",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.DropIndex(
                name: "UQ_Subjects_ProgramID_SubjectCode",
                table: "Subjects");

            migrationBuilder.CreateIndex(
                name: "IX_UserDetails_CurriculumID",
                table: "UserDetails",
                column: "CurriculumID");

            migrationBuilder.CreateIndex(
                name: "IX_Subjects_ProgramID",
                table: "Subjects",
                column: "ProgramID");

            migrationBuilder.CreateIndex(
                name: "UQ_Subjects_CurriculumID_SubjectCode",
                table: "Subjects",
                columns: new[] { "CurriculumID", "SubjectCode" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "UQ_Curricula_ProgramID_EffectiveFromYear",
                table: "Curricula",
                columns: new[] { "ProgramID", "EffectiveFromYear" },
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Subjects_Curricula_CurriculumID",
                table: "Subjects",
                column: "CurriculumID",
                principalTable: "Curricula",
                principalColumn: "CurriculumID",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_UserDetails_Curricula_CurriculumID",
                table: "UserDetails",
                column: "CurriculumID",
                principalTable: "Curricula",
                principalColumn: "CurriculumID",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Subjects_Curricula_CurriculumID",
                table: "Subjects");

            migrationBuilder.DropForeignKey(
                name: "FK_UserDetails_Curricula_CurriculumID",
                table: "UserDetails");

            migrationBuilder.DropTable(
                name: "Curricula");

            migrationBuilder.DropIndex(
                name: "IX_UserDetails_CurriculumID",
                table: "UserDetails");

            migrationBuilder.DropIndex(
                name: "IX_Subjects_ProgramID",
                table: "Subjects");

            migrationBuilder.DropIndex(
                name: "UQ_Subjects_CurriculumID_SubjectCode",
                table: "Subjects");

            migrationBuilder.DropColumn(
                name: "CurriculumID",
                table: "UserDetails");

            migrationBuilder.DropColumn(
                name: "CurriculumID",
                table: "Subjects");

            migrationBuilder.CreateIndex(
                name: "UQ_Subjects_ProgramID_SubjectCode",
                table: "Subjects",
                columns: new[] { "ProgramID", "SubjectCode" },
                unique: true);
        }
    }
}
