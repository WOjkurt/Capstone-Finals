using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class UpdateAcademicDomainSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_EnrollmentApplications_Students_StudentID",
                table: "EnrollmentApplications");

            migrationBuilder.DropForeignKey(
                name: "FK_EnrollmentApplications_Users_UserID",
                table: "EnrollmentApplications");

            migrationBuilder.DropForeignKey(
                name: "FK_Grades_Users_UserID",
                table: "Grades");

            migrationBuilder.DropForeignKey(
                name: "FK_StudyLoads_Students_StudentID",
                table: "StudyLoads");

            migrationBuilder.DropTable(
                name: "Students");

            migrationBuilder.DropColumn(
                name: "Data",
                table: "EnrollmentResponses");

            migrationBuilder.DropColumn(
                name: "ApplicantName",
                table: "EnrollmentApplications");

            migrationBuilder.DropColumn(
                name: "Email",
                table: "EnrollmentApplications");

            migrationBuilder.DropColumn(
                name: "FinalWeight",
                table: "Classes");

            migrationBuilder.DropColumn(
                name: "MidtermWeight",
                table: "Classes");

            migrationBuilder.RenameColumn(
                name: "Semester",
                table: "Subjects",
                newName: "DefaultSemester");

            migrationBuilder.RenameColumn(
                name: "StudentID",
                table: "StudyLoads",
                newName: "UserID");

            migrationBuilder.RenameIndex(
                name: "IX_StudyLoads_StudentID",
                table: "StudyLoads",
                newName: "IX_StudyLoads_UserID");

            migrationBuilder.RenameColumn(
                name: "UserID",
                table: "Grades",
                newName: "SubmittedByUserID");

            migrationBuilder.RenameIndex(
                name: "IX_Grades_UserID",
                table: "Grades",
                newName: "IX_Grades_SubmittedByUserID");

            migrationBuilder.RenameColumn(
                name: "GradePeriod",
                table: "GradeCorrections",
                newName: "CorrectionPeriod");

            migrationBuilder.RenameColumn(
                name: "UserID",
                table: "EnrollmentApplications",
                newName: "StudentUserID");

            migrationBuilder.RenameColumn(
                name: "StudentID",
                table: "EnrollmentApplications",
                newName: "ReviewedByUserID");

            migrationBuilder.RenameIndex(
                name: "IX_EnrollmentApplications_UserID",
                table: "EnrollmentApplications",
                newName: "IX_EnrollmentApplications_StudentUserID");

            migrationBuilder.RenameIndex(
                name: "IX_EnrollmentApplications_StudentID",
                table: "EnrollmentApplications",
                newName: "IX_EnrollmentApplications_ReviewedByUserID");

            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAt",
                table: "StudyLoads",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedByUserID",
                table: "StudyLoads",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAt",
                table: "EnrollmentApplications",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedByUserID",
                table: "EnrollmentApplications",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "CreatedAt",
                table: "Classes",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<Guid>(
                name: "CreatedByUserID",
                table: "Classes",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "EnrollmentForms",
                columns: table => new
                {
                    EnrollmentID = table.Column<Guid>(type: "uuid", nullable: false),
                    ApplicationID = table.Column<Guid>(type: "uuid", nullable: false),
                    FirstName = table.Column<string>(type: "text", nullable: false),
                    MiddleName = table.Column<string>(type: "text", nullable: false),
                    LastName = table.Column<string>(type: "text", nullable: false),
                    Suffix = table.Column<string>(type: "text", nullable: false),
                    DateOfBirth = table.Column<DateOnly>(type: "date", nullable: false),
                    PlaceOfBirth = table.Column<string>(type: "text", nullable: false),
                    Sex = table.Column<string>(type: "text", nullable: false),
                    CivilStatus = table.Column<string>(type: "text", nullable: false),
                    Nationality = table.Column<string>(type: "text", nullable: false),
                    MobileNumber = table.Column<string>(type: "text", nullable: false),
                    Barangay = table.Column<string>(type: "text", nullable: false),
                    CityMunicipality = table.Column<string>(type: "text", nullable: false),
                    Province = table.Column<string>(type: "text", nullable: false),
                    ZipCode = table.Column<string>(type: "text", nullable: false),
                    LastSchoolAttended = table.Column<string>(type: "text", nullable: false),
                    SchoolAddress = table.Column<string>(type: "text", nullable: false),
                    SHSStrand = table.Column<int>(type: "integer", nullable: false),
                    YearGraduated = table.Column<DateOnly>(type: "date", nullable: false),
                    PreviousCollege = table.Column<string>(type: "text", nullable: false),
                    PreviousCourse = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EnrollmentForms", x => x.EnrollmentID);
                    table.ForeignKey(
                        name: "FK_EnrollmentForms_EnrollmentApplications_ApplicationID",
                        column: x => x.ApplicationID,
                        principalTable: "EnrollmentApplications",
                        principalColumn: "ApplicationID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Positions",
                columns: table => new
                {
                    PositionID = table.Column<Guid>(type: "uuid", nullable: false),
                    PositionName = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Positions", x => x.PositionID);
                });

            migrationBuilder.CreateTable(
                name: "Contacts",
                columns: table => new
                {
                    ContactID = table.Column<Guid>(type: "uuid", nullable: false),
                    EnrollmentID = table.Column<Guid>(type: "uuid", nullable: false),
                    FirstName = table.Column<string>(type: "text", nullable: false),
                    LastName = table.Column<string>(type: "text", nullable: false),
                    RelationType = table.Column<int>(type: "integer", nullable: false),
                    Occupation = table.Column<string>(type: "text", nullable: false),
                    ContactNo = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Contacts", x => x.ContactID);
                    table.ForeignKey(
                        name: "FK_Contacts_EnrollmentForms_EnrollmentID",
                        column: x => x.EnrollmentID,
                        principalTable: "EnrollmentForms",
                        principalColumn: "EnrollmentID",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "UserDetails",
                columns: table => new
                {
                    UserDetailID = table.Column<Guid>(type: "uuid", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    Firstname = table.Column<string>(type: "text", nullable: false),
                    Lastname = table.Column<string>(type: "text", nullable: false),
                    LRN = table.Column<string>(type: "text", nullable: true),
                    ProgramID = table.Column<int>(type: "integer", nullable: true),
                    StudentType = table.Column<int>(type: "integer", nullable: true),
                    StudentStatus = table.Column<int>(type: "integer", nullable: true),
                    YearLevel = table.Column<int>(type: "integer", nullable: true),
                    EmployeeID = table.Column<int>(type: "integer", nullable: true),
                    PositionID = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_UserDetails", x => x.UserDetailID);
                    table.ForeignKey(
                        name: "FK_UserDetails_AcademicPrograms_ProgramID",
                        column: x => x.ProgramID,
                        principalTable: "AcademicPrograms",
                        principalColumn: "ProgramID",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_UserDetails_Positions_PositionID",
                        column: x => x.PositionID,
                        principalTable: "Positions",
                        principalColumn: "PositionID",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_UserDetails_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_StudyLoads_CreatedByUserID",
                table: "StudyLoads",
                column: "CreatedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentApplications_CreatedByUserID",
                table: "EnrollmentApplications",
                column: "CreatedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_Classes_CreatedByUserID",
                table: "Classes",
                column: "CreatedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_Contacts_EnrollmentID",
                table: "Contacts",
                column: "EnrollmentID");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentForms_ApplicationID",
                table: "EnrollmentForms",
                column: "ApplicationID");

            migrationBuilder.CreateIndex(
                name: "IX_UserDetails_PositionID",
                table: "UserDetails",
                column: "PositionID");

            migrationBuilder.CreateIndex(
                name: "IX_UserDetails_ProgramID",
                table: "UserDetails",
                column: "ProgramID");

            migrationBuilder.CreateIndex(
                name: "UQ_UserDetails_UserID",
                table: "UserDetails",
                column: "UserID",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Classes_Users_CreatedByUserID",
                table: "Classes",
                column: "CreatedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_EnrollmentApplications_Users_CreatedByUserID",
                table: "EnrollmentApplications",
                column: "CreatedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_EnrollmentApplications_Users_ReviewedByUserID",
                table: "EnrollmentApplications",
                column: "ReviewedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_EnrollmentApplications_Users_StudentUserID",
                table: "EnrollmentApplications",
                column: "StudentUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Grades_Users_SubmittedByUserID",
                table: "Grades",
                column: "SubmittedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_StudyLoads_Users_CreatedByUserID",
                table: "StudyLoads",
                column: "CreatedByUserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_StudyLoads_Users_UserID",
                table: "StudyLoads",
                column: "UserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Classes_Users_CreatedByUserID",
                table: "Classes");

            migrationBuilder.DropForeignKey(
                name: "FK_EnrollmentApplications_Users_CreatedByUserID",
                table: "EnrollmentApplications");

            migrationBuilder.DropForeignKey(
                name: "FK_EnrollmentApplications_Users_ReviewedByUserID",
                table: "EnrollmentApplications");

            migrationBuilder.DropForeignKey(
                name: "FK_EnrollmentApplications_Users_StudentUserID",
                table: "EnrollmentApplications");

            migrationBuilder.DropForeignKey(
                name: "FK_Grades_Users_SubmittedByUserID",
                table: "Grades");

            migrationBuilder.DropForeignKey(
                name: "FK_StudyLoads_Users_CreatedByUserID",
                table: "StudyLoads");

            migrationBuilder.DropForeignKey(
                name: "FK_StudyLoads_Users_UserID",
                table: "StudyLoads");

            migrationBuilder.DropTable(
                name: "Contacts");

            migrationBuilder.DropTable(
                name: "UserDetails");

            migrationBuilder.DropTable(
                name: "EnrollmentForms");

            migrationBuilder.DropTable(
                name: "Positions");

            migrationBuilder.DropIndex(
                name: "IX_StudyLoads_CreatedByUserID",
                table: "StudyLoads");

            migrationBuilder.DropIndex(
                name: "IX_EnrollmentApplications_CreatedByUserID",
                table: "EnrollmentApplications");

            migrationBuilder.DropIndex(
                name: "IX_Classes_CreatedByUserID",
                table: "Classes");

            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "StudyLoads");

            migrationBuilder.DropColumn(
                name: "CreatedByUserID",
                table: "StudyLoads");

            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "EnrollmentApplications");

            migrationBuilder.DropColumn(
                name: "CreatedByUserID",
                table: "EnrollmentApplications");

            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "Classes");

            migrationBuilder.DropColumn(
                name: "CreatedByUserID",
                table: "Classes");

            migrationBuilder.RenameColumn(
                name: "DefaultSemester",
                table: "Subjects",
                newName: "Semester");

            migrationBuilder.RenameColumn(
                name: "UserID",
                table: "StudyLoads",
                newName: "StudentID");

            migrationBuilder.RenameIndex(
                name: "IX_StudyLoads_UserID",
                table: "StudyLoads",
                newName: "IX_StudyLoads_StudentID");

            migrationBuilder.RenameColumn(
                name: "SubmittedByUserID",
                table: "Grades",
                newName: "UserID");

            migrationBuilder.RenameIndex(
                name: "IX_Grades_SubmittedByUserID",
                table: "Grades",
                newName: "IX_Grades_UserID");

            migrationBuilder.RenameColumn(
                name: "CorrectionPeriod",
                table: "GradeCorrections",
                newName: "GradePeriod");

            migrationBuilder.RenameColumn(
                name: "StudentUserID",
                table: "EnrollmentApplications",
                newName: "UserID");

            migrationBuilder.RenameColumn(
                name: "ReviewedByUserID",
                table: "EnrollmentApplications",
                newName: "StudentID");

            migrationBuilder.RenameIndex(
                name: "IX_EnrollmentApplications_StudentUserID",
                table: "EnrollmentApplications",
                newName: "IX_EnrollmentApplications_UserID");

            migrationBuilder.RenameIndex(
                name: "IX_EnrollmentApplications_ReviewedByUserID",
                table: "EnrollmentApplications",
                newName: "IX_EnrollmentApplications_StudentID");

            migrationBuilder.AddColumn<string>(
                name: "Data",
                table: "EnrollmentResponses",
                type: "jsonb",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "ApplicantName",
                table: "EnrollmentApplications",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<string>(
                name: "Email",
                table: "EnrollmentApplications",
                type: "text",
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<decimal>(
                name: "FinalWeight",
                table: "Classes",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "MidtermWeight",
                table: "Classes",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateTable(
                name: "Students",
                columns: table => new
                {
                    StudentID = table.Column<Guid>(type: "uuid", nullable: false),
                    ProgramID = table.Column<int>(type: "integer", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    Email = table.Column<string>(type: "text", nullable: false),
                    Firstname = table.Column<string>(type: "text", nullable: false),
                    LRN = table.Column<string>(type: "text", nullable: false),
                    Lastname = table.Column<string>(type: "text", nullable: false),
                    StudentStatus = table.Column<int>(type: "integer", nullable: false),
                    StudentType = table.Column<int>(type: "integer", nullable: false),
                    YearLevel = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Students", x => x.StudentID);
                    table.ForeignKey(
                        name: "FK_Students_AcademicPrograms_ProgramID",
                        column: x => x.ProgramID,
                        principalTable: "AcademicPrograms",
                        principalColumn: "ProgramID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Students_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Students_ProgramID",
                table: "Students",
                column: "ProgramID");

            migrationBuilder.CreateIndex(
                name: "UQ_Students_UserID",
                table: "Students",
                column: "UserID",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_EnrollmentApplications_Students_StudentID",
                table: "EnrollmentApplications",
                column: "StudentID",
                principalTable: "Students",
                principalColumn: "StudentID",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_EnrollmentApplications_Users_UserID",
                table: "EnrollmentApplications",
                column: "UserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.SetNull);

            migrationBuilder.AddForeignKey(
                name: "FK_Grades_Users_UserID",
                table: "Grades",
                column: "UserID",
                principalTable: "Users",
                principalColumn: "UserID",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_StudyLoads_Students_StudentID",
                table: "StudyLoads",
                column: "StudentID",
                principalTable: "Students",
                principalColumn: "StudentID",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
