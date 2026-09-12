using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Api.Migrations
{
    /// <inheritdoc />
    public partial class AddEnrollmentFormExpansionColumns : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "AcademicYear",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Age",
                table: "EnrollmentForms",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BirthOrder",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "BloodType",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DevelopmentalConditions",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FacebookName",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FamilyMedicalConditionsNotes",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FamilyMedicalConditionsSelected",
                table: "EnrollmentForms",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FamilyStatus",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Gender",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ImmunizationHistory",
                table: "EnrollmentForms",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "IncomingCourse",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "LRN",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "NumberOfSiblings",
                table: "EnrollmentForms",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OngoingMedications",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "OtherMedicalDiagnosis",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PastMedicalHistory",
                table: "EnrollmentForms",
                type: "jsonb",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProvBarangay",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProvCityMunicipality",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProvHouseStreet",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProvProvince",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ProvZipCode",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Religion",
                table: "EnrollmentForms",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "StudentType",
                table: "EnrollmentForms",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "DateOfBirth",
                table: "Contacts",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Email",
                table: "Contacts",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "FacebookAccount",
                table: "Contacts",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "LivingWithGuardian",
                table: "Contacts",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Workplace",
                table: "Contacts",
                type: "text",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "AcademicYear",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "Age",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "BirthOrder",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "BloodType",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "DevelopmentalConditions",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "FacebookName",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "FamilyMedicalConditionsNotes",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "FamilyMedicalConditionsSelected",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "FamilyStatus",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "Gender",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "ImmunizationHistory",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "IncomingCourse",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "LRN",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "NumberOfSiblings",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "OngoingMedications",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "OtherMedicalDiagnosis",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "PastMedicalHistory",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "ProvBarangay",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "ProvCityMunicipality",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "ProvHouseStreet",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "ProvProvince",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "ProvZipCode",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "Religion",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "StudentType",
                table: "EnrollmentForms");

            migrationBuilder.DropColumn(
                name: "DateOfBirth",
                table: "Contacts");

            migrationBuilder.DropColumn(
                name: "Email",
                table: "Contacts");

            migrationBuilder.DropColumn(
                name: "FacebookAccount",
                table: "Contacts");

            migrationBuilder.DropColumn(
                name: "LivingWithGuardian",
                table: "Contacts");

            migrationBuilder.DropColumn(
                name: "Workplace",
                table: "Contacts");
        }
    }
}
