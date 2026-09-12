using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class RenameShsStrandToProgramTrackStrand : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Safe column type change: integer → text with data preservation.
            // EF's auto-generated DropColumn + AddColumn would silently discard all
            // existing SHSStrand values. This raw SQL approach converts them first.
            migrationBuilder.Sql("""
                ALTER TABLE "EnrollmentForms" ADD COLUMN "ProgramTrackStrand" text NULL;

                UPDATE "EnrollmentForms" SET "ProgramTrackStrand" = CASE
                    WHEN "SHSStrand" = 1 THEN 'STEM'
                    WHEN "SHSStrand" = 2 THEN 'HUMSS'
                    WHEN "SHSStrand" = 3 THEN 'ABM'
                    WHEN "SHSStrand" = 4 THEN 'GAS'
                    WHEN "SHSStrand" = 5 THEN 'TVL'
                    ELSE NULL
                END;

                ALTER TABLE "EnrollmentForms" DROP COLUMN "SHSStrand";
                """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Reverse: restore SHSStrand integer from ProgramTrackStrand text.
            // Unrecognized values (e.g. free-text from the new form) map to 0 (unknown).
            migrationBuilder.Sql("""
                ALTER TABLE "EnrollmentForms" ADD COLUMN "SHSStrand" integer NOT NULL DEFAULT 0;

                UPDATE "EnrollmentForms" SET "SHSStrand" = CASE
                    WHEN "ProgramTrackStrand" = 'STEM'  THEN 1
                    WHEN "ProgramTrackStrand" = 'HUMSS' THEN 2
                    WHEN "ProgramTrackStrand" = 'ABM'   THEN 3
                    WHEN "ProgramTrackStrand" = 'GAS'   THEN 4
                    WHEN "ProgramTrackStrand" = 'TVL'   THEN 5
                    ELSE 0
                END;

                ALTER TABLE "EnrollmentForms" DROP COLUMN "ProgramTrackStrand";
                """);
        }
    }
}
