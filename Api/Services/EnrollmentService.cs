using System.Text.Json;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Enrollment;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Api.Constants;

namespace Api.Services;

public class EnrollmentService : IEnrollmentService
{
    private readonly AppDbContext _context;
    private readonly IEnrollmentResponseRepository _responseRepository;
    private readonly IEnrollmentApplicationRepository _applicationRepository;
    private readonly IEnrollmentFormRepository _formRepository;
    private readonly IContactRepository _contactRepository;
    private readonly IUserDetailsRepository _userDetailsRepository;
    private readonly IUserRepository _userRepository;
    private readonly ILogger<EnrollmentService> _logger;

    public EnrollmentService(
        AppDbContext context,
        IEnrollmentResponseRepository responseRepository,
        IEnrollmentApplicationRepository applicationRepository,
        IEnrollmentFormRepository formRepository,
        IContactRepository contactRepository,
        IUserDetailsRepository userDetailsRepository,
        IUserRepository userRepository,
        ILogger<EnrollmentService> logger)
    {
        _context = context;
        _responseRepository = responseRepository;
        _applicationRepository = applicationRepository;
        _formRepository = formRepository;
        _contactRepository = contactRepository;
        _userDetailsRepository = userDetailsRepository;
        _userRepository = userRepository;
        _logger = logger;
    }

    public async Task<Guid> CreateResponseAsync(CreateEnrollmentResponseDto dto)
    {
        var formData = dto.Form ?? new ResponseFormDataDto();

        // Extract contacts: prefer dto.Contacts, fallback to dto.Form?.Contacts
        var contacts = dto.Contacts.Count > 0 
            ? dto.Contacts 
            : (formData.Contacts ?? []);

        var responseData = new ResponseDataDto
        {
            Form = formData,
            Contacts = contacts
        };

        SanitizeWebhookPayload(responseData);

        // Serialize the applicant's form submission to jsonb.
        // Round-trip via JsonSerializer so Npgsql receives a proper JsonDocument.
        var jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = false
        };
        var dataJson = JsonSerializer.Serialize(responseData, jsonOptions);

        var response = new EnrollmentResponse
        {
            ResponseID = Guid.NewGuid(),
            EmailAddress = dto.EmailAddress,
            IsProcessed = false,
            Timestamp = DateTime.UtcNow,
            Data = JsonDocument.Parse(dataJson)
        };

        await _responseRepository.AddAsync(response);
        return response.ResponseID;
    }

    private void SanitizeWebhookPayload(ResponseDataDto responseData)
    {
        string? Truncate(string? value, int maxLen, string fieldName)
        {
            if (string.IsNullOrWhiteSpace(value)) return null;
            var trimmed = value.Trim();
            if (trimmed.Length > maxLen)
            {
                _logger.LogWarning("Webhook payload field '{FieldName}' exceeded max length {MaxLength} (was {ActualLength}). Truncating silently.", fieldName, maxLen, trimmed.Length);
                return trimmed.Substring(0, maxLen);
            }
            return trimmed;
        }

        var f = responseData.Form;
        if (f != null)
        {
            f.FirstName = Truncate(f.FirstName, ValidationConstants.NameMax, nameof(f.FirstName)) ?? string.Empty;
            f.MiddleName = Truncate(f.MiddleName, ValidationConstants.ShortMax, nameof(f.MiddleName));
            f.LastName = Truncate(f.LastName, ValidationConstants.NameMax, nameof(f.LastName)) ?? string.Empty;
            f.Suffix = Truncate(f.Suffix, ValidationConstants.ShortMax, nameof(f.Suffix));
            f.DateOfBirth = Truncate(f.DateOfBirth, ValidationConstants.DateStringMax, nameof(f.DateOfBirth));
            f.PlaceOfBirth = Truncate(f.PlaceOfBirth, ValidationConstants.AddressMax, nameof(f.PlaceOfBirth));
            f.Sex = Truncate(f.Sex, ValidationConstants.ShortMax, nameof(f.Sex));
            f.CivilStatus = Truncate(f.CivilStatus, ValidationConstants.ShortMax, nameof(f.CivilStatus));
            f.Nationality = Truncate(f.Nationality, ValidationConstants.ShortMax, nameof(f.Nationality));
            f.Gender = Truncate(f.Gender, ValidationConstants.ShortMax, nameof(f.Gender));
            f.BloodType = Truncate(f.BloodType, ValidationConstants.ShortMax, nameof(f.BloodType));
            f.Religion = Truncate(f.Religion, ValidationConstants.ShortMax, nameof(f.Religion));
            f.FacebookName = Truncate(f.FacebookName, ValidationConstants.NameMax, nameof(f.FacebookName));
            f.MobileNumber = Truncate(f.MobileNumber, ValidationConstants.PhoneMax, nameof(f.MobileNumber));
            f.HouseStreet = Truncate(f.HouseStreet, ValidationConstants.LongAddressMax, nameof(f.HouseStreet));
            f.Barangay = Truncate(f.Barangay, ValidationConstants.AddressMax, nameof(f.Barangay));
            f.CityOfMunicipality = Truncate(f.CityOfMunicipality, ValidationConstants.AddressMax, nameof(f.CityOfMunicipality));
            f.Province = Truncate(f.Province, ValidationConstants.AddressMax, nameof(f.Province));
            f.ZipCode = Truncate(f.ZipCode, ValidationConstants.ZipCodeMax, nameof(f.ZipCode));
            f.ProvHouseStreet = Truncate(f.ProvHouseStreet, ValidationConstants.AddressMax, nameof(f.ProvHouseStreet));
            f.ProvBarangay = Truncate(f.ProvBarangay, ValidationConstants.AddressMax, nameof(f.ProvBarangay));
            f.ProvCityMunicipality = Truncate(f.ProvCityMunicipality, ValidationConstants.AddressMax, nameof(f.ProvCityMunicipality));
            f.ProvProvince = Truncate(f.ProvProvince, ValidationConstants.AddressMax, nameof(f.ProvProvince));
            f.ProvZipCode = Truncate(f.ProvZipCode, ValidationConstants.ZipCodeMax, nameof(f.ProvZipCode));
            f.LastSchoolAttended = Truncate(f.LastSchoolAttended, ValidationConstants.LongAddressMax, nameof(f.LastSchoolAttended));
            f.SchoolAddress = Truncate(f.SchoolAddress, ValidationConstants.LongAddressMax, nameof(f.SchoolAddress));
            f.ProgramTrackStrand = Truncate(f.ProgramTrackStrand, ValidationConstants.AddressMax, nameof(f.ProgramTrackStrand));
            f.YearGraduated = Truncate(f.YearGraduated, ValidationConstants.DateStringMax, nameof(f.YearGraduated));
            f.PreviousCollege = Truncate(f.PreviousCollege, ValidationConstants.AddressMax, nameof(f.PreviousCollege));
            f.PreviousCourse = Truncate(f.PreviousCourse, ValidationConstants.AddressMax, nameof(f.PreviousCourse));
            f.LRN = Truncate(f.LRN, ValidationConstants.ShortMax, nameof(f.LRN));
            f.AcademicYear = Truncate(f.AcademicYear, ValidationConstants.DateStringMax, nameof(f.AcademicYear));
            f.IncomingCourse = Truncate(f.IncomingCourse, ValidationConstants.AddressMax, nameof(f.IncomingCourse));
            f.PreviousStudentID = Truncate(f.PreviousStudentID, ValidationConstants.ShortMax, nameof(f.PreviousStudentID));
            f.IntendedProgramCode = Truncate(f.IntendedProgramCode, ValidationConstants.ShortMax, nameof(f.IntendedProgramCode));
            f.BirthOrder = Truncate(f.BirthOrder, ValidationConstants.ShortMax, nameof(f.BirthOrder));
            f.FamilyStatus = Truncate(f.FamilyStatus, ValidationConstants.ShortMax, nameof(f.FamilyStatus));
            f.FamilyMedicalConditionsNotes = Truncate(f.FamilyMedicalConditionsNotes, ValidationConstants.NotesMax, nameof(f.FamilyMedicalConditionsNotes));
            f.OngoingMedications = Truncate(f.OngoingMedications, ValidationConstants.NotesMax, nameof(f.OngoingMedications));
            f.DevelopmentalConditions = Truncate(f.DevelopmentalConditions, ValidationConstants.NotesMax, nameof(f.DevelopmentalConditions));
            f.OtherMedicalDiagnosis = Truncate(f.OtherMedicalDiagnosis, ValidationConstants.NotesMax, nameof(f.OtherMedicalDiagnosis));

            void TruncateList(List<string>? list, int maxLen, string listName)
            {
                if (list == null) return;
                for (int i = 0; i < list.Count; i++)
                {
                    list[i] = Truncate(list[i], maxLen, $"{listName}[{i}]") ?? string.Empty;
                }
            }

            TruncateList(f.PresentMedicalConditions, ValidationConstants.NameMax, nameof(f.PresentMedicalConditions));
            TruncateList(f.PastMedicalHistory, ValidationConstants.NameMax, nameof(f.PastMedicalHistory));
            TruncateList(f.ImmunizationHistory, ValidationConstants.NameMax, nameof(f.ImmunizationHistory));
        }

        foreach (var c in responseData.Contacts)
        {
            c.FirstName = Truncate(c.FirstName, ValidationConstants.NameMax, nameof(c.FirstName)) ?? string.Empty;
            c.LastName = Truncate(c.LastName, ValidationConstants.NameMax, nameof(c.LastName)) ?? string.Empty;
            c.Occupation = Truncate(c.Occupation, ValidationConstants.AddressMax, nameof(c.Occupation));
            c.ContactNo = Truncate(c.ContactNo, ValidationConstants.PhoneMax, nameof(c.ContactNo)) ?? string.Empty;
            c.Email = Truncate(c.Email, 320, nameof(c.Email));
            c.DateOfBirth = Truncate(c.DateOfBirth, ValidationConstants.DateStringMax, nameof(c.DateOfBirth));
            c.Workplace = Truncate(c.Workplace, ValidationConstants.AddressMax, nameof(c.Workplace));
            c.FacebookAccount = Truncate(c.FacebookAccount, ValidationConstants.NameMax, nameof(c.FacebookAccount));
            c.GuardianRelationshipDescription = Truncate(c.GuardianRelationshipDescription, ValidationConstants.AddressMax, nameof(c.GuardianRelationshipDescription));
            
            // Also apply fallback deserializers manually if needed, though they happen on property set.
        }
    }

    public async Task<List<EnrollmentResponseDto>> GetUnprocessedResponsesAsync()
    {
        var responses = await _responseRepository.GetUnprocessedAsync();
        return responses.Select(r => new EnrollmentResponseDto
        {
            ResponseID = r.ResponseID,
            Timestamp = r.Timestamp,
            EmailAddress = r.EmailAddress,
            IsProcessed = r.IsProcessed,
            Data = DeserializeData(r.Data)
        }).ToList();
    }

    /// <summary>
    /// Returns a single enrollment response by ID, including its parsed form data.
    /// Used by the Registrar to pre-fill the review form before processing.
    /// </summary>
    public async Task<EnrollmentResponseDto?> GetResponseByIdAsync(Guid responseId)
    {
        var response = await _responseRepository.GetByIdAsync(responseId);
        if (response == null) return null;

        return new EnrollmentResponseDto
        {
            ResponseID = response.ResponseID,
            Timestamp = response.Timestamp,
            EmailAddress = response.EmailAddress,
            IsProcessed = response.IsProcessed,
            Data = DeserializeData(response.Data)
        };
    }

    /// <summary>
    /// Deserializes the stored JsonDocument back into a ResponseDataDto.
    /// Returns null if the column is null (responses created before Data was introduced).
    /// </summary>
    private static ResponseDataDto? DeserializeData(JsonDocument? doc)
    {
        if (doc == null) return null;
        var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };

        // Handle case where doc has a root "form" / "Form" wrapper
        if (doc.RootElement.ValueKind == JsonValueKind.Object &&
            (doc.RootElement.TryGetProperty("form", out _) || doc.RootElement.TryGetProperty("Form", out _)))
        {
            return JsonSerializer.Deserialize<ResponseDataDto>(doc.RootElement.GetRawText(), options);
        }

        // Backward-compatibility if stored flat
        var flatForm = JsonSerializer.Deserialize<ResponseFormDataDto>(doc.RootElement.GetRawText(), options);
        var contacts = flatForm?.Contacts ?? [];
        return new ResponseDataDto
        {
            Form = flatForm,
            Contacts = contacts
        };
    }

    public async Task<Guid> CreateApplicationAsync(CreateEnrollmentApplicationDto dto, Guid createdByUserId)
    {
        var response = await _responseRepository.GetByIdAsync(dto.ResponseID);
        if (response == null)
        {
            throw new KeyNotFoundException($"EnrollmentResponse with ID '{dto.ResponseID}' was not found.");
        }
        if (response.IsProcessed)
        {
            throw new InvalidOperationException($"EnrollmentResponse with ID '{dto.ResponseID}' has already been processed.");
        }

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var application = new EnrollmentApplication
            {
                ApplicationID = Guid.NewGuid(),
                ResponseID = dto.ResponseID,
                ProgramID = dto.ProgramID,
                TermID = dto.TermID,
                Status = EnrollmentApplicationStatus.Pending, // 1 = Pending
                CreatedByUserID = createdByUserId,
                CreatedAt = DateTime.UtcNow
            };
            await _applicationRepository.AddAsync(application);

            var form = new EnrollmentForm
            {
                EnrollmentID = Guid.NewGuid(),
                ApplicationID = application.ApplicationID,
                // ── Name ────────────────────────────────────────────────────
                FirstName = dto.Form.FirstName,
                MiddleName = dto.Form.MiddleName,
                LastName = dto.Form.LastName,
                Suffix = dto.Form.Suffix,
                // ── Personal ────────────────────────────────────────────────
                DateOfBirth = dto.Form.DateOfBirth,
                PlaceOfBirth = dto.Form.PlaceOfBirth,
                Sex = dto.Form.Sex,
                CivilStatus = dto.Form.CivilStatus,
                Nationality = dto.Form.Nationality,
                Gender = dto.Form.Gender,
                Age = dto.Form.Age,
                BloodType = dto.Form.BloodType,
                Religion = dto.Form.Religion,
                FacebookName = dto.Form.FacebookName,
                // ── Primary Address ─────────────────────────────────────────
                MobileNumber = dto.Form.MobileNumber,
                HouseStreet = dto.Form.HouseStreet,
                Barangay = dto.Form.Barangay,
                CityMunicipality = dto.Form.CityMunicipality,
                Province = dto.Form.Province,
                ZipCode = dto.Form.ZipCode,
                // ── Secondary / Provincial Address ──────────────────────────
                ProvHouseStreet = dto.Form.ProvHouseStreet,
                ProvBarangay = dto.Form.ProvBarangay,
                ProvCityMunicipality = dto.Form.ProvCityMunicipality,
                ProvProvince = dto.Form.ProvProvince,
                ProvZipCode = dto.Form.ProvZipCode,
                // ── Educational ─────────────────────────────────────────────
                LastSchoolAttended = dto.Form.LastSchoolAttended,
                SchoolAddress = dto.Form.SchoolAddress,
                ProgramTrackStrand = dto.Form.ProgramTrackStrand,
                YearGraduated = dto.Form.YearGraduated,
                PreviousCollege = dto.Form.PreviousCollege,
                PreviousCourse = dto.Form.PreviousCourse,
                // ── Enrollment Metadata ─────────────────────────────────────
                YearLevel = dto.Form.YearLevel,
                StudentType = dto.Form.StudentType,
                LRN = dto.Form.LRN,
                AcademicYear = dto.Form.AcademicYear,
                IncomingCourse = dto.Form.IncomingCourse,
                PreviousStudentID = dto.Form.PreviousStudentID,
                // ── Family Information ───────────────────────────────────────
                BirthOrder = dto.Form.BirthOrder,
                NumberOfSiblings = dto.Form.NumberOfSiblings,
                FamilyStatus = dto.Form.FamilyStatus,
                // ── Medical Multi-Select ────────────────────────────────────
                FamilyMedicalConditionsSelected = dto.Form.FamilyMedicalConditionsSelected,
                PastMedicalHistory = dto.Form.PastMedicalHistory,
                ImmunizationHistory = dto.Form.ImmunizationHistory,
                // ── Family Health History (free text) ───────────────────────
                FamilyMedicalConditionsNotes = dto.Form.FamilyMedicalConditionsNotes,
                OngoingMedications = dto.Form.OngoingMedications,
                DevelopmentalConditions = dto.Form.DevelopmentalConditions,
                OtherMedicalDiagnosis = dto.Form.OtherMedicalDiagnosis
            };
            await _formRepository.AddAsync(form);

            if (dto.Contacts != null && dto.Contacts.Count > 0)
            {
                foreach (var cDto in dto.Contacts)
                {
                    var contact = new Contact
                    {
                        ContactID = Guid.NewGuid(),
                        EnrollmentID = form.EnrollmentID,
                        FirstName = cDto.FirstName,
                        LastName = cDto.LastName,
                        RelationType = cDto.RelationType,
                        Occupation = cDto.Occupation,
                        ContactNo = cDto.ContactNo,
                        // ── Extended contact fields ──────────────────────────
                        Email = cDto.Email,
                        DateOfBirth = cDto.DateOfBirth,
                        Workplace = cDto.Workplace,
                        FacebookAccount = cDto.FacebookAccount,
                        LivingWithGuardian = cDto.LivingWithGuardian,
                        GuardianRelationshipDescription = cDto.GuardianRelationshipDescription
                    };
                    await _contactRepository.AddAsync(contact);
                }
            }

            response.IsProcessed = true;
            await _responseRepository.UpdateAsync(response);

            await transaction.CommitAsync();
            return application.ApplicationID;
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }

    public async Task ApproveApplicationAsync(Guid applicationId, Guid reviewedByUserId, int? yearLevelOverride = null)
    {
        var application = await _applicationRepository.GetByIdAsync(applicationId);
        if (application == null)
        {
            throw new KeyNotFoundException($"EnrollmentApplication with ID '{applicationId}' was not found.");
        }

        if (application.Status != EnrollmentApplicationStatus.Pending) // 1 = Pending
        {
            throw new InvalidOperationException($"Application cannot be approved because its current status is not Pending (Status: {application.Status}).");
        }

        // If the registrar provides a YearLevel override, write it directly onto the form
        // so LinkAccountAsync always has a single source of truth: the form.
        if (yearLevelOverride.HasValue)
        {
            var form = await _formRepository.GetByApplicationIdAsync(applicationId);
            if (form != null)
            {
                form.YearLevel = yearLevelOverride.Value;
                await _formRepository.UpdateAsync(form);
            }
        }

        application.Status = EnrollmentApplicationStatus.Approved; // 2 = Approved
        application.ReviewedByUserID = reviewedByUserId;
        await _applicationRepository.UpdateAsync(application);
    }

    public async Task RejectApplicationAsync(Guid applicationId, Guid reviewedByUserId, string? reason)
    {
        var application = await _applicationRepository.GetByIdAsync(applicationId);
        if (application == null)
        {
            throw new KeyNotFoundException($"EnrollmentApplication with ID '{applicationId}' was not found.");
        }

        if (application.Status != EnrollmentApplicationStatus.Pending) // 1 = Pending
        {
            throw new InvalidOperationException($"Application cannot be rejected because its current status is not Pending (Status: {application.Status}).");
        }

        application.Status = EnrollmentApplicationStatus.Rejected; // 3 = Rejected
        application.ReviewedByUserID = reviewedByUserId;
        await _applicationRepository.UpdateAsync(application);
    }

    public async Task<EnrollmentApplicationResponseDto> LinkAccountAsync(Guid applicationId, string email, Guid reviewedByUserId)
    {
        var application = await _applicationRepository.GetByIdAsync(applicationId);
        if (application == null)
        {
            throw new KeyNotFoundException($"EnrollmentApplication with ID '{applicationId}' was not found.");
        }

        if (application.Status != EnrollmentApplicationStatus.Approved) // 2 = Approved
        {
            throw new InvalidOperationException($"Application cannot be linked because its current status is not Approved (Status: {application.Status}).");
        }

        var user = await _userRepository.GetByEmailAsync(email);
        if (user == null)
        {
            throw new InvalidOperationException("No account found for this email. The student must log in at least once before linking.");
        }

        var existingUserDetails = await _userDetailsRepository.GetByUserIdAsync(user.UserID);
        if (existingUserDetails != null)
        {
            throw new InvalidOperationException($"A student profile (UserDetails) already exists for user account '{email}'.");
        }

        var form = await _formRepository.GetByApplicationIdAsync(applicationId);
        if (form == null)
        {
            throw new InvalidOperationException($"Linked EnrollmentForm for application '{applicationId}' was not found.");
        }

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var userDetails = new UserDetails
            {
                UserDetailID = Guid.NewGuid(),
                UserID = user.UserID,
                Firstname = form.FirstName,
                Lastname = form.LastName,
                ProgramID = application.ProgramID,
                StudentType = 1,   // New
                StudentStatus = 1, // Enrolled
                YearLevel = form.YearLevel, // Read from form (may have been overridden by registrar at approval time)
                IsRegular = true
            };
            await _userDetailsRepository.AddAsync(userDetails);

            application.StudentUserID = user.UserID;
            application.Status = EnrollmentApplicationStatus.Active; // 4 = Active
            application.ReviewedByUserID = reviewedByUserId;
            await _applicationRepository.UpdateAsync(application);

            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }

        var updated = await GetApplicationByIdAsync(applicationId);
        return updated!;
    }

    public async Task<EnrollmentApplicationResponseDto?> GetApplicationByIdAsync(Guid applicationId)
    {
        var application = await _applicationRepository.GetByIdAsync(applicationId);
        if (application == null)
        {
            return null;
        }

        return await MapToDtoAsync(application);
    }

    public async Task<List<EnrollmentApplicationResponseDto>> GetApprovedApplicationsAsync()
    {
        return await GetApplicationsAsync(EnrollmentApplicationStatus.Approved);
    }

    public async Task<List<EnrollmentApplicationResponseDto>> GetApplicationsAsync(int? status = null)
    {
        var applications = status.HasValue
            ? await _applicationRepository.GetByStatusAsync(status.Value)
            : await _applicationRepository.GetAllAsync();

        var result = new List<EnrollmentApplicationResponseDto>();
        foreach (var app in applications)
        {
            result.Add(await MapToDtoAsync(app));
        }

        return result;
    }

    private async Task<EnrollmentApplicationResponseDto> MapToDtoAsync(EnrollmentApplication application)
    {
        var form = await _formRepository.GetByApplicationIdAsync(application.ApplicationID);
        List<Contact> contacts = new();
        if (form != null)
        {
            contacts = await _contactRepository.GetByEnrollmentIdAsync(form.EnrollmentID);
        }

        UserDetailsDto? userDetailsDto = null;
        if (application.StudentUserID.HasValue && application.StudentUserID.Value != Guid.Empty)
        {
            var ud = await _userDetailsRepository.GetByUserIdAsync(application.StudentUserID.Value);
            if (ud != null)
            {
                userDetailsDto = new UserDetailsDto
                {
                    UserDetailID = ud.UserDetailID,
                    UserID = ud.UserID,
                    Firstname = ud.Firstname,
                    Lastname = ud.Lastname,
                    LRN = ud.LRN,
                    ProgramID = ud.ProgramID,
                    StudentType = ud.StudentType,
                    StudentStatus = ud.StudentStatus,
                    YearLevel = ud.YearLevel,
                    EmployeeID = ud.EmployeeID,
                    PositionID = ud.PositionID,
                    IsRegular = ud.IsRegular
                };
            }
        }

        return new EnrollmentApplicationResponseDto
        {
            ApplicationID = application.ApplicationID,
            ResponseID = application.ResponseID,
            ProgramID = application.ProgramID,
            TermID = application.TermID,
            Status = application.Status,
            ReviewedByUserID = application.ReviewedByUserID,
            StudentUserID = application.StudentUserID,
            CreatedAt = application.CreatedAt,
            CreatedByUserID = application.CreatedByUserID,
            UserDetails = userDetailsDto,
            Form = form == null ? null : new EnrollmentFormDto
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
            },
            Contacts = contacts.Select(c => new ContactDto
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
            }).ToList()
        };
    }
}
