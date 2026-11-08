using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Enrollment;

namespace Api.Services;

/// <summary>Copies an enrollment form and its contacts between the database and the API, field by field.</summary>
public static class EnrollmentFormMapping
{
    public static EnrollmentForm ToEntity(EnrollmentFormDto dto, Guid applicationId) => new()
    {
        EnrollmentID = Guid.NewGuid(),
        ApplicationID = applicationId,
        // ── Name ────────────────────────────────────────────────────
        FirstName = dto.FirstName,
        MiddleName = dto.MiddleName,
        LastName = dto.LastName,
        Suffix = dto.Suffix,
        // ── Personal ────────────────────────────────────────────────
        DateOfBirth = dto.DateOfBirth,
        PlaceOfBirth = dto.PlaceOfBirth,
        Sex = dto.Sex,
        CivilStatus = dto.CivilStatus,
        Nationality = dto.Nationality,
        Gender = dto.Gender,
        Age = dto.Age,
        BloodType = dto.BloodType,
        Religion = dto.Religion,
        FacebookName = dto.FacebookName,
        // ── Primary Address ─────────────────────────────────────────
        MobileNumber = dto.MobileNumber,
        HouseStreet = dto.HouseStreet,
        Barangay = dto.Barangay,
        CityMunicipality = dto.CityMunicipality,
        Province = dto.Province,
        ZipCode = dto.ZipCode,
        // ── Secondary / Provincial Address ──────────────────────────
        ProvHouseStreet = dto.ProvHouseStreet,
        ProvBarangay = dto.ProvBarangay,
        ProvCityMunicipality = dto.ProvCityMunicipality,
        ProvProvince = dto.ProvProvince,
        ProvZipCode = dto.ProvZipCode,
        // ── Educational ─────────────────────────────────────────────
        LastSchoolAttended = dto.LastSchoolAttended,
        SchoolAddress = dto.SchoolAddress,
        ProgramTrackStrand = dto.ProgramTrackStrand,
        YearGraduated = dto.YearGraduated,
        PreviousCollege = dto.PreviousCollege,
        PreviousCourse = dto.PreviousCourse,
        // ── Enrollment Metadata ─────────────────────────────────────
        YearLevel = dto.YearLevel,
        StudentType = dto.StudentType,
        LRN = LrnHelper.Normalize(dto.LRN).IsValid ? LrnHelper.Normalize(dto.LRN).Lrn : null,
        AcademicYear = dto.AcademicYear,
        IncomingCourse = dto.IncomingCourse,
        PreviousStudentID = dto.PreviousStudentID,
        // ── Family Information ───────────────────────────────────────
        BirthOrder = dto.BirthOrder,
        NumberOfSiblings = dto.NumberOfSiblings,
        FamilyStatus = dto.FamilyStatus,
        // ── Medical Multi-Select ────────────────────────────────────
        FamilyMedicalConditionsSelected = dto.FamilyMedicalConditionsSelected,
        PastMedicalHistory = dto.PastMedicalHistory,
        ImmunizationHistory = dto.ImmunizationHistory,
        // ── Family Health History (free text) ───────────────────────
        FamilyMedicalConditionsNotes = dto.FamilyMedicalConditionsNotes,
        OngoingMedications = dto.OngoingMedications,
        DevelopmentalConditions = dto.DevelopmentalConditions,
        OtherMedicalDiagnosis = dto.OtherMedicalDiagnosis
    };

    public static Contact ToEntity(ContactDto c, Guid enrollmentId) => new()
    {
        ContactID = Guid.NewGuid(),
        EnrollmentID = enrollmentId,
        FirstName = c.FirstName,
        LastName = c.LastName,
        RelationType = c.RelationType,
        Occupation = c.Occupation,
        ContactNo = c.ContactNo,
        // ── Extended contact fields ──────────────────────────
        Email = c.Email,
        DateOfBirth = c.DateOfBirth,
        Workplace = c.Workplace,
        FacebookAccount = c.FacebookAccount,
        LivingWithGuardian = c.LivingWithGuardian,
        GuardianRelationshipDescription = c.GuardianRelationshipDescription
    };

    public static EnrollmentFormDto ToDto(EnrollmentForm form) => new()
    {
        // ── Name ────────────────────────────────────────────────────
        FirstName = form.FirstName,
        MiddleName = form.MiddleName,
        LastName = form.LastName,
        Suffix = form.Suffix,
        // ── Personal ────────────────────────────────────────────────
        DateOfBirth = form.DateOfBirth,
        PlaceOfBirth = form.PlaceOfBirth,
        Sex = form.Sex,
        CivilStatus = form.CivilStatus,
        Nationality = form.Nationality,
        Gender = form.Gender,
        Age = form.Age,
        BloodType = form.BloodType,
        Religion = form.Religion,
        FacebookName = form.FacebookName,
        // ── Primary Address ─────────────────────────────────────────
        MobileNumber = form.MobileNumber,
        HouseStreet = form.HouseStreet,
        Barangay = form.Barangay,
        CityMunicipality = form.CityMunicipality,
        Province = form.Province,
        ZipCode = form.ZipCode,
        // ── Secondary / Provincial Address ──────────────────────────
        ProvHouseStreet = form.ProvHouseStreet,
        ProvBarangay = form.ProvBarangay,
        ProvCityMunicipality = form.ProvCityMunicipality,
        ProvProvince = form.ProvProvince,
        ProvZipCode = form.ProvZipCode,
        // ── Educational ─────────────────────────────────────────────
        LastSchoolAttended = form.LastSchoolAttended,
        SchoolAddress = form.SchoolAddress,
        ProgramTrackStrand = form.ProgramTrackStrand,
        YearGraduated = form.YearGraduated,
        PreviousCollege = form.PreviousCollege,
        PreviousCourse = form.PreviousCourse,
        // ── Enrollment Metadata ─────────────────────────────────────
        YearLevel = form.YearLevel,
        StudentType = form.StudentType,
        LRN = form.LRN,
        AcademicYear = form.AcademicYear,
        IncomingCourse = form.IncomingCourse,
        PreviousStudentID = form.PreviousStudentID,
        // ── Family Information ───────────────────────────────────────
        BirthOrder = form.BirthOrder,
        NumberOfSiblings = form.NumberOfSiblings,
        FamilyStatus = form.FamilyStatus,
        // ── Medical Multi-Select ────────────────────────────────────
        FamilyMedicalConditionsSelected = form.FamilyMedicalConditionsSelected,
        PastMedicalHistory = form.PastMedicalHistory,
        ImmunizationHistory = form.ImmunizationHistory,
        // ── Family Health History (free text) ───────────────────────
        FamilyMedicalConditionsNotes = form.FamilyMedicalConditionsNotes,
        OngoingMedications = form.OngoingMedications,
        DevelopmentalConditions = form.DevelopmentalConditions,
        OtherMedicalDiagnosis = form.OtherMedicalDiagnosis
    };

    public static ContactDto ToDto(Contact c) => new()
    {
        FirstName = c.FirstName,
        LastName = c.LastName,
        RelationType = c.RelationType,
        Occupation = c.Occupation,
        ContactNo = c.ContactNo,
        // ── Extended contact fields ──────────────────────────────────
        Email = c.Email,
        DateOfBirth = c.DateOfBirth,
        Workplace = c.Workplace,
        FacebookAccount = c.FacebookAccount,
        LivingWithGuardian = c.LivingWithGuardian,
        GuardianRelationshipDescription = c.GuardianRelationshipDescription
    };
}
