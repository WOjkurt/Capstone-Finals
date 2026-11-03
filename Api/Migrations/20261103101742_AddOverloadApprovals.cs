using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddOverloadApprovals : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "OverloadApprovals",
                columns: table => new
                {
                    OverloadApprovalID = table.Column<Guid>(type: "uuid", nullable: false),
                    UserID = table.Column<Guid>(type: "uuid", nullable: false),
                    TermID = table.Column<Guid>(type: "uuid", nullable: false),
                    Units = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    MaxUnits = table.Column<decimal>(type: "numeric(5,1)", precision: 5, scale: 1, nullable: false),
                    Reason = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    ApprovedByUserID = table.Column<Guid>(type: "uuid", nullable: false),
                    ApprovedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_OverloadApprovals", x => x.OverloadApprovalID);
                    table.ForeignKey(
                        name: "FK_OverloadApprovals_AcademicTerms_TermID",
                        column: x => x.TermID,
                        principalTable: "AcademicTerms",
                        principalColumn: "TermID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_OverloadApprovals_Users_ApprovedByUserID",
                        column: x => x.ApprovedByUserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_OverloadApprovals_Users_UserID",
                        column: x => x.UserID,
                        principalTable: "Users",
                        principalColumn: "UserID",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_OverloadApprovals_ApprovedByUserID",
                table: "OverloadApprovals",
                column: "ApprovedByUserID");

            migrationBuilder.CreateIndex(
                name: "IX_OverloadApprovals_TermID",
                table: "OverloadApprovals",
                column: "TermID");

            migrationBuilder.CreateIndex(
                name: "UQ_OverloadApprovals_UserID_TermID",
                table: "OverloadApprovals",
                columns: new[] { "UserID", "TermID" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "OverloadApprovals");
        }
    }
}
