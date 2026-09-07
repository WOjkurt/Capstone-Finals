using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class InitialAcademicDomain : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AcademicPrograms",
                columns: table => new
                {
                    ProgramID = table.Column<int>(type: "integer", nullable: false)
                        .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn),
                    ProgramCode = table.Column<string>(type: "text", nullable: false),
                    ProgramName = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AcademicPrograms", x => x.ProgramID);
                });

            migrationBuilder.CreateTable(
                name: "AcademicTerms",
                columns: table => new
                {
                    TermID = table.Column<Guid>(type: "uuid", nullable: false),
                    SchoolYear = table.Column<string>(type: "text", nullable: false),
                    Semester = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AcademicTerms", x => x.TermID);
                });

            migrationBuilder.CreateTable(
                name: "EnrollmentResponses",
                columns: table => new
                {
                    ResponseID = table.Column<Guid>(type: "uuid", nullable: false),
                    Timestamp = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    EmailAddress = table.Column<string>(type: "text", nullable: false),
                    Data = table.Column<string>(type: "jsonb", nullable: false),
                    IsProcessed = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EnrollmentResponses", x => x.ResponseID);
                });

            migrationBuilder.CreateTable(
                name: "Subjects",
                columns: table => new
                {
                    SubjectID = table.Column<Guid>(type: "uuid", nullable: false),
                    SubjectCode = table.Column<string>(type: "text", nullable: false),
                    SubjectTitle = table.Column<string>(type: "text", nullable: false),
                    LecUnits = table.Column<decimal>(type: "numeric", nullable: false),
                    LabUnits = table.Column<decimal>(type: "numeric", nullable: false),
                    LecHours = table.Column<decimal>(type: "numeric", nullable: false),
                    LabHours = table.Column<decimal>(type: "numeric", nullable: false),
                    ProgramID = table.Column<int>(type: "integer", nullable: false),
                    YearLevel = table.Column<int>(type: "integer", nullable: false),
                    Semester = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Subjects", x => x.SubjectID);
                    table.ForeignKey(
                        name: "FK_Subjects_AcademicPrograms_ProgramID",
                        column: x => x.ProgramID,
                        principalTable: "AcademicPrograms",
                        principalColumn: "ProgramID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Users",
                columns: table => new
                {
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    FirebaseUID = table.Column<string>(type: "text", nullable: false),
                    Email = table.Column<string>(type: "text", nullable: false),
                    FirstName = table.Column<string>(type: "text", nullable: false),
                    LastName = table.Column<string>(type: "text", nullable: false),
                    Role = table.Column<int>(type: "integer", nullable: false),
                    ProgramID = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Users", x => x.UserID);
                    table.ForeignKey(
                        name: "FK_Users_AcademicPrograms_ProgramID",
                        column: x => x.ProgramID,
                        principalTable: "AcademicPrograms",
                        principalColumn: "ProgramID",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "SubjectPrerequisites",
                columns: table => new
                {
                    PrerequisiteID = table.Column<Guid>(type: "uuid", nullable: false),
                    SubjectID = table.Column<Guid>(type: "uuid", nullable: false),
                    PrerequisiteSubjectID = table.Column<Guid>(type: "uuid", nullable: false),
                    RequisiteType = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SubjectPrerequisites", x => x.PrerequisiteID);
                    table.ForeignKey(
                        name: "FK_SubjectPrerequisites_Subjects_PrerequisiteSubjectID",
                        column: x => x.PrerequisiteSubjectID,
                        principalTable: "Subjects",
                        principalColumn: "SubjectID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_SubjectPrerequisites_Subjects_SubjectID",
                        column: x => x.SubjectID,
                        principalTable: "Subjects",
                        principalColumn: "SubjectID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Classes",
                columns: table => new
                {
                    ClassID = table.Column<Guid>(type: "uuid", nullable: false),
                    SubjectID = table.Column<Guid>(type: "uuid", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: true),
                    TermID = table.Column<Guid>(type: "uuid", nullable: false),
                    ClassName = table.Column<string>(type: "text", nullable: false),
                    MidtermWeight = table.Column<decimal>(type: "numeric", nullable: false),
                    FinalWeight = table.Column<decimal>(type: "numeric", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Classes", x => x.ClassID);
                    table.ForeignKey(
                        name: "FK_Classes_AcademicTerms_TermID",
                        column: x => x.TermID,
                        principalTable: "AcademicTerms",
                        principalColumn: "TermID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Classes_Subjects_SubjectID",
                        column: x => x.SubjectID,
                        principalTable: "Subjects",
                        principalColumn: "SubjectID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Classes_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "Students",
                columns: table => new
                {
                    StudentID = table.Column<Guid>(type: "uuid", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    Firstname = table.Column<string>(type: "text", nullable: false),
                    Lastname = table.Column<string>(type: "text", nullable: false),
                    Email = table.Column<string>(type: "text", nullable: false),
                    LRN = table.Column<string>(type: "text", nullable: false),
                    ProgramID = table.Column<int>(type: "integer", nullable: false),
                    StudentType = table.Column<int>(type: "integer", nullable: false),
                    StudentStatus = table.Column<int>(type: "integer", nullable: false),
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

            migrationBuilder.CreateTable(
                name: "ClassSchedules",
                columns: table => new
                {
                    ScheduleID = table.Column<Guid>(type: "uuid", nullable: false),
                    ClassID = table.Column<Guid>(type: "uuid", nullable: false),
                    DaysOfWeek = table.Column<string>(type: "text", nullable: false),
                    StartTime = table.Column<TimeOnly>(type: "time without time zone", nullable: false),
                    EndTime = table.Column<TimeOnly>(type: "time without time zone", nullable: false),
                    Room = table.Column<string>(type: "text", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ClassSchedules", x => x.ScheduleID);
                    table.ForeignKey(
                        name: "FK_ClassSchedules_Classes_ClassID",
                        column: x => x.ClassID,
                        principalTable: "Classes",
                        principalColumn: "ClassID",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "EnrollmentApplications",
                columns: table => new
                {
                    ApplicationID = table.Column<Guid>(type: "uuid", nullable: false),
                    ResponseID = table.Column<Guid>(type: "uuid", nullable: false),
                    ApplicantName = table.Column<string>(type: "text", nullable: false),
                    Email = table.Column<string>(type: "text", nullable: false),
                    ProgramID = table.Column<int>(type: "integer", nullable: false),
                    TermID = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: true),
                    StudentID = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_EnrollmentApplications", x => x.ApplicationID);
                    table.ForeignKey(
                        name: "FK_EnrollmentApplications_AcademicPrograms_ProgramID",
                        column: x => x.ProgramID,
                        principalTable: "AcademicPrograms",
                        principalColumn: "ProgramID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_EnrollmentApplications_AcademicTerms_TermID",
                        column: x => x.TermID,
                        principalTable: "AcademicTerms",
                        principalColumn: "TermID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_EnrollmentApplications_EnrollmentResponses_ResponseID",
                        column: x => x.ResponseID,
                        principalTable: "EnrollmentResponses",
                        principalColumn: "ResponseID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_EnrollmentApplications_Students_StudentID",
                        column: x => x.StudentID,
                        principalTable: "Students",
                        principalColumn: "StudentID",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_EnrollmentApplications_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "StudyLoads",
                columns: table => new
                {
                    StudyLoadID = table.Column<Guid>(type: "uuid", nullable: false),
                    StudentID = table.Column<Guid>(type: "uuid", nullable: false),
                    ClassID = table.Column<Guid>(type: "uuid", nullable: false),
                    LoadStatus = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StudyLoads", x => x.StudyLoadID);
                    table.ForeignKey(
                        name: "FK_StudyLoads_Classes_ClassID",
                        column: x => x.ClassID,
                        principalTable: "Classes",
                        principalColumn: "ClassID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_StudyLoads_Students_StudentID",
                        column: x => x.StudentID,
                        principalTable: "Students",
                        principalColumn: "StudentID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "Grades",
                columns: table => new
                {
                    GradeID = table.Column<Guid>(type: "uuid", nullable: false),
                    StudyLoadID = table.Column<Guid>(type: "uuid", nullable: false),
                    MidtermGrade = table.Column<decimal>(type: "numeric", nullable: false),
                    FinalGrade = table.Column<decimal>(type: "numeric", nullable: false),
                    Remarks = table.Column<int>(type: "integer", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    DateSubmitted = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Grades", x => x.GradeID);
                    table.ForeignKey(
                        name: "FK_Grades_StudyLoads_StudyLoadID",
                        column: x => x.StudyLoadID,
                        principalTable: "StudyLoads",
                        principalColumn: "StudyLoadID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Grades_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "GradeCorrections",
                columns: table => new
                {
                    CorrectionID = table.Column<Guid>(type: "uuid", nullable: false),
                    GradeID = table.Column<Guid>(type: "uuid", nullable: false),
                    GradePeriod = table.Column<int>(type: "integer", nullable: false),
                    OldGrade = table.Column<decimal>(type: "numeric", nullable: false),
                    NewGrade = table.Column<decimal>(type: "numeric", nullable: false),
                    Reason = table.Column<string>(type: "text", nullable: false),
                    RequestedByUserID = table.Column<Guid>(type: "uuid", nullable: false),
                    ReviewedByUserID = table.Column<Guid>(type: "uuid", nullable: false),
                    CorrectionStatus = table.Column<int>(type: "integer", nullable: false),
                    DateRequested = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    DateReviewed = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GradeCorrections", x => x.CorrectionID);
                    table.ForeignKey(
                        name: "FK_GradeCorrections_Grades_GradeID",
                        column: x => x.GradeID,
                        principalTable: "Grades",
                        principalColumn: "GradeID",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_GradeCorrections_Users_RequestedByUserID",
                        column: x => x.RequestedByUserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GradeCorrections_Users_ReviewedByUserID",
                        column: x => x.ReviewedByUserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Classes_SubjectID",
                table: "Classes",
                column: "SubjectID");

            migrationBuilder.CreateIndex(
                name: "IX_Classes_TermID",
                table: "Classes",
                column: "TermID");

            migrationBuilder.CreateIndex(
                name: "IX_Classes_UserID",
                table: "Classes",
                column: "UserID");

            migrationBuilder.CreateIndex(
                name: "IX_ClassSchedules_ClassID",
                table: "ClassSchedules",
                column: "ClassID");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentApplications_ProgramID",
                table: "EnrollmentApplications",
                column: "ProgramID");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentApplications_ResponseID",
                table: "EnrollmentApplications",
                column: "ResponseID");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentApplications_StudentID",
                table: "EnrollmentApplications",
                column: "StudentID");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentApplications_TermID",
                table: "EnrollmentApplications",
                column: "TermID");

            migrationBuilder.CreateIndex(
                name: "IX_EnrollmentApplications_UserID",
                table: "EnrollmentApplications",
                column: "UserID");

            migrationBuilder.CreateIndex(
                name: "IX_GradeCorrections_GradeID",
                table: "GradeCorrections",
                column: "GradeID");

            migrationBuilder.CreateIndex(
                name: "IX_GradeCorrections_RequestedByUserID",
                table: "GradeCorrections",
                column: "RequestedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_GradeCorrections_ReviewedByUserID",
                table: "GradeCorrections",
                column: "ReviewedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_Grades_StudyLoadID",
                table: "Grades",
                column: "StudyLoadID");

            migrationBuilder.CreateIndex(
                name: "IX_Grades_UserID",
                table: "Grades",
                column: "UserID");

            migrationBuilder.CreateIndex(
                name: "IX_Students_ProgramID",
                table: "Students",
                column: "ProgramID");

            migrationBuilder.CreateIndex(
                name: "UQ_Students_UserID",
                table: "Students",
                column: "UserID",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StudyLoads_ClassID",
                table: "StudyLoads",
                column: "ClassID");

            migrationBuilder.CreateIndex(
                name: "IX_StudyLoads_StudentID",
                table: "StudyLoads",
                column: "StudentID");

            migrationBuilder.CreateIndex(
                name: "IX_SubjectPrerequisites_PrerequisiteSubjectID",
                table: "SubjectPrerequisites",
                column: "PrerequisiteSubjectID");

            migrationBuilder.CreateIndex(
                name: "IX_SubjectPrerequisites_SubjectID",
                table: "SubjectPrerequisites",
                column: "SubjectID");

            migrationBuilder.CreateIndex(
                name: "IX_Subjects_ProgramID",
                table: "Subjects",
                column: "ProgramID");

            migrationBuilder.CreateIndex(
                name: "IX_Users_ProgramID",
                table: "Users",
                column: "ProgramID");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ClassSchedules");

            migrationBuilder.DropTable(
                name: "EnrollmentApplications");

            migrationBuilder.DropTable(
                name: "GradeCorrections");

            migrationBuilder.DropTable(
                name: "SubjectPrerequisites");

            migrationBuilder.DropTable(
                name: "EnrollmentResponses");

            migrationBuilder.DropTable(
                name: "Grades");

            migrationBuilder.DropTable(
                name: "StudyLoads");

            migrationBuilder.DropTable(
                name: "Classes");

            migrationBuilder.DropTable(
                name: "Students");

            migrationBuilder.DropTable(
                name: "AcademicTerms");

            migrationBuilder.DropTable(
                name: "Subjects");

            migrationBuilder.DropTable(
                name: "Users");

            migrationBuilder.DropTable(
                name: "AcademicPrograms");
        }
    }
}
