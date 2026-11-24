using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class DropGradeCorrections : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GradeCorrections");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "GradeCorrections",
                columns: table => new
                {
                    CorrectionID = table.Column<Guid>(type: "uuid", nullable: false),
                    GradeID = table.Column<Guid>(type: "uuid", nullable: false),
                    RequestedByUserID = table.Column<Guid>(type: "uuid", nullable: false),
                    ReviewedByUserID = table.Column<Guid>(type: "uuid", nullable: true),
                    CorrectionPeriod = table.Column<int>(type: "integer", nullable: false),
                    CorrectionStatus = table.Column<int>(type: "integer", nullable: false),
                    DateRequested = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    DateReviewed = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    NewGrade = table.Column<decimal>(type: "numeric", nullable: false),
                    OldGrade = table.Column<decimal>(type: "numeric", nullable: false),
                    Reason = table.Column<string>(type: "text", nullable: false)
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
                        onDelete: ReferentialAction.SetNull);
                });

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
        }
    }
}
