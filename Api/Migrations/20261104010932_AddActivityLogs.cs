using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddActivityLogs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ActivityLogs",
                columns: table => new
                {
                    ActivityLogID = table.Column<Guid>(type: "uuid", nullable: false),
                    OccurredAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ActorUserID = table.Column<Guid>(type: "uuid", nullable: true),
                    ActorName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    ActorRole = table.Column<int>(type: "integer", nullable: true),
                    Action = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    StudentUserID = table.Column<Guid>(type: "uuid", nullable: true),
                    StudentName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    TermID = table.Column<Guid>(type: "uuid", nullable: true),
                    Summary = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ActivityLogs", x => x.ActivityLogID);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ActivityLogs_Action",
                table: "ActivityLogs",
                column: "Action");

            migrationBuilder.CreateIndex(
                name: "IX_ActivityLogs_OccurredAt",
                table: "ActivityLogs",
                column: "OccurredAt");

            migrationBuilder.CreateIndex(
                name: "IX_ActivityLogs_StudentUserID",
                table: "ActivityLogs",
                column: "StudentUserID");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ActivityLogs");
        }
    }
}
