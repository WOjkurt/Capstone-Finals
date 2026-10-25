using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.Grading;
using Api.Domain.IdentityAccess;
using Api.DTOs.Setup;
using Api.DTOs.StudyLoad;
using Api.Repositories;
using Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Xunit;

namespace Api.Tests;

public class StandingYearAndUniqueSubjectCodeTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly SubjectService _subjectService;
    private readonly StudyLoadService _studyLoadService;
    private readonly SubjectsController _subjectsController;

    private readonly Guid _registrarId = Guid.NewGuid();
    private readonly Guid _collegeHeadId = Guid.NewGuid();
    private readonly Guid _teacherId = Guid.NewGuid();
    private readonly Guid _studentId = Guid.NewGuid();

    public StandingYearAndUniqueSubjectCodeTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _context = new TestAppDbContext(options);

        var subjectRepo = new SubjectRepository(_context);
        var prereqRepo = new SubjectPrerequisiteRepository(_context);
        var programRepo = new AcademicProgramRepository(_context);
        _subjectService = new SubjectService(_context, subjectRepo, prereqRepo, programRepo);

        var studyLoadRepo = new StudyLoadRepository(_context);
        var clearanceRepo = new GradeClearanceRepository(_context);
        var clearanceService = new GradeClearanceService(_context, clearanceRepo);
        _studyLoadService = new StudyLoadService(
            _context, studyLoadRepo, clearanceService, NullLogger<StudyLoadService>.Instance);

        _subjectsController = new SubjectsController(_subjectService);

        SeedUsersAndPrograms();
    }

    private void SeedUsersAndPrograms()
    {
        _context.AcademicPrograms.AddRange(
            new AcademicProgram { ProgramID = 1, ProgramCode = "BSIT", ProgramName = "BS Information Technology" },
            new AcademicProgram { ProgramID = 2, ProgramCode = "BSCS", ProgramName = "BS Computer Science" }
        );

        _context.Users.AddRange(
            new User { UserID = _registrarId, FirebaseUID = "fb-reg", Email = "reg@dbtc.edu.ph", Role = RoleUtils.Registrar, IsActive = true },
            new User { UserID = _collegeHeadId, FirebaseUID = "fb-ch", Email = "ch@dbtc.edu.ph", Role = RoleUtils.CollegeHead, IsActive = true },
            new User { UserID = _teacherId, FirebaseUID = "fb-teach", Email = "teach@dbtc.edu.ph", Role = RoleUtils.Teacher, IsActive = true },
            new User { UserID = _studentId, FirebaseUID = "fb-stud", Email = "stud@dbtc.edu.ph", Role = RoleUtils.Student, IsActive = true }
        );

        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    // ── 1. Unique Subject Code per Program ────────────────────────────────────

    [Fact]
    public async Task CreateAsync_DuplicateSubjectCodeInSameProgram_ThrowsInvalidOperationException()
    {
        var dto1 = new CreateSubjectDto
        {
            SubjectCode = "IT 104A",
            SubjectTitle = "Web Development",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        };
        await _subjectService.CreateAsync(dto1);

        var dto2 = new CreateSubjectDto
        {
            SubjectCode = "  it   104a  ",
            SubjectTitle = "Web Dev Duplicate",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        };

        var ex = await Assert.ThrowsAsync<DuplicateSubjectCodeException>(() => _subjectService.CreateAsync(dto2));
        Assert.Contains("IT 104A", ex.Message);
        Assert.Contains("BSIT", ex.Message);
    }

    [Fact]
    public async Task CreateAsync_SameSubjectCodeInDifferentPrograms_Succeeds()
    {
        var itSubject = await _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = "GEC 101A",
            SubjectTitle = "Understanding the Self (IT)",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        });

        var csSubject = await _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = "GEC 101A",
            SubjectTitle = "Understanding the Self (CS)",
            ProgramID = 2,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        });

        Assert.NotNull(itSubject);
        Assert.NotNull(csSubject);
        Assert.NotEqual(itSubject.SubjectID, csSubject.SubjectID);
        Assert.Equal("GEC 101A", itSubject.SubjectCode);
        Assert.Equal("GEC 101A", csSubject.SubjectCode);
    }

    // ── 2. Normalization of Subject Code ──────────────────────────────────────

    [Fact]
    public async Task CreateAsync_NormalizesSubjectCode_TrimsCollapsesRepeatedSpacesAndUppercases()
    {
        var subject1 = await _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = " it   104a ",
            SubjectTitle = "Test Subject",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        });

        Assert.Equal("IT 104A", subject1.SubjectCode);

        var subject2 = await _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = "cs101",
            SubjectTitle = "Test Subject 2",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        });

        Assert.Equal("CS101", subject2.SubjectCode);
    }

    [Fact]
    public async Task UpdateAsync_NormalizesSubjectCode_AndChecksDuplicates()
    {
        var s1 = await _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = "IT 101",
            SubjectTitle = "Subject 1",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        });

        var s2 = await _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = "IT 102",
            SubjectTitle = "Subject 2",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        });

        // Updating s2 with normalized spaces
        var updated = await _subjectService.UpdateAsync(s2.SubjectID, new CreateSubjectDto
        {
            SubjectCode = "  it   102b  ",
            SubjectTitle = "Subject 2 Updated",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        });
        Assert.Equal("IT 102B", updated.SubjectCode);

        // Updating s2 to match s1 should throw
        await Assert.ThrowsAsync<DuplicateSubjectCodeException>(() => _subjectService.UpdateAsync(s2.SubjectID, new CreateSubjectDto
        {
            SubjectCode = "  it   101  ",
            SubjectTitle = "Conflict with s1",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        }));
    }

    // ── 3. StandingYear Validation ────────────────────────────────────────────

    [Theory]
    [InlineData(1)]
    [InlineData(2)]
    [InlineData(3)]
    [InlineData(4)]
    public async Task StandingYear_ValidValues1To4_Accepted(int standingYear)
    {
        var result = await _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = $"IT {standingYear}01",
            SubjectTitle = $"Year {standingYear} Subject",
            ProgramID = 1,
            YearLevel = standingYear,
            DefaultSemester = 1,
            StandingYear = standingYear,
            LecUnits = 3
        });

        Assert.Equal(standingYear, result.StandingYear);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(5)]
    [InlineData(-1)]
    public async Task StandingYear_InvalidValues_ThrowsArgumentException(int invalidStandingYear)
    {
        await Assert.ThrowsAsync<ArgumentException>(() => _subjectService.CreateAsync(new CreateSubjectDto
        {
            SubjectCode = "IT ERR",
            SubjectTitle = "Invalid Standing Subject",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            StandingYear = invalidStandingYear,
            LecUnits = 3
        }));
    }

    // ── 4. Controller HTTP Mapping ───────────────────────────────────────────

    [Fact]
    public async Task SubjectsController_Create_DuplicateSubjectCode_Returns409Conflict()
    {
        var dto = new CreateSubjectDto
        {
            SubjectCode = "IT DUP",
            SubjectTitle = "Original",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            LecUnits = 3
        };
        await _subjectsController.Create(dto);

        var actionResult = await _subjectsController.Create(dto);
        var conflictResult = Assert.IsType<ConflictObjectResult>(actionResult);
        Assert.Equal(409, conflictResult.StatusCode);
    }

    [Fact]
    public async Task SubjectsController_Create_InvalidStandingYear_Returns400BadRequest()
    {
        var dto = new CreateSubjectDto
        {
            SubjectCode = "IT INV",
            SubjectTitle = "Invalid Standing",
            ProgramID = 1,
            YearLevel = 1,
            DefaultSemester = 1,
            StandingYear = 5,
            LecUnits = 3
        };

        var actionResult = await _subjectsController.Create(dto);
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(actionResult);
        Assert.Equal(400, badRequestResult.StatusCode);
    }

    // ── 5. Standing Rule in ValidateEnrollmentRulesAsync ──────────────────────

    private async Task<(Subject subject, Class cls, AcademicTerm term)> SeedClassWithSubjectAsync(
        string code, int? standingYear)
    {
        var term = new AcademicTerm
        {
            TermID = Guid.NewGuid(),
            SchoolYear = "2025-2026",
            Semester = 1,
            IsActive = true
        };
        _context.AcademicTerms.Add(term);

        var subject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = code,
            SubjectTitle = code + " Title",
            ProgramID = 1,
            YearLevel = 3,
            DefaultSemester = 1,
            StandingYear = standingYear,
            LecUnits = 3
        };
        _context.Subjects.Add(subject);

        var cls = new Class
        {
            ClassID = Guid.NewGuid(),
            ClassName = code + "-SecA",
            SubjectID = subject.SubjectID,
            TermID = term.TermID,
            CreatedAt = DateTime.UtcNow
        };
        _context.Classes.Add(cls);
        await _context.SaveChangesAsync();

        return (subject, cls, term);
    }

    [Fact]
    public async Task StandingRule_StudentYearLevelGreaterOrEqual_PassesSilently()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 301", standingYear: 3);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s1",
            Email = "s1@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "John",
            Lastname = "Doe",
            ProgramID = 1,
            YearLevel = 3
        });
        await _context.SaveChangesAsync();

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, cls.ClassID, term.TermID);
        Assert.DoesNotContain(findings, f => f.Code == EnrollmentRuleCodes.StandingYearRequired || f.Code == EnrollmentRuleCodes.YearLevelNotSet);
    }

    [Fact]
    public async Task StandingRule_SubjectStandingYearNull_PassesSilently()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 101", standingYear: null);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s2",
            Email = "s2@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Jane",
            Lastname = "Doe",
            ProgramID = 1,
            YearLevel = 1
        });
        await _context.SaveChangesAsync();

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, cls.ClassID, term.TermID);
        Assert.DoesNotContain(findings, f => f.Code == EnrollmentRuleCodes.StandingYearRequired || f.Code == EnrollmentRuleCodes.YearLevelNotSet);
    }

    [Fact]
    public async Task StandingRule_StudentYearLevelLower_ReturnsFinding()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 302", standingYear: 3);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s3",
            Email = "s3@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Low",
            Lastname = "Year",
            ProgramID = 1,
            YearLevel = 2
        });
        await _context.SaveChangesAsync();

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, cls.ClassID, term.TermID);
        var finding = Assert.Single(findings, f => f.Code == EnrollmentRuleCodes.StandingYearRequired);
        Assert.True(finding.CanForce);
        Assert.Contains("requires Year 3 standing", finding.Message);
        Assert.Contains("student is Year 2", finding.Message);
    }

    [Fact]
    public async Task StandingRule_StudentYearLevelNull_ReturnsFindingThatCannotBeForced()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 401", standingYear: 4);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s4",
            Email = "s4@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        // UserDetails with null YearLevel
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "No",
            Lastname = "Year",
            ProgramID = 1,
            YearLevel = null
        });
        await _context.SaveChangesAsync();

        var findings = await _studyLoadService.ValidateEnrollmentRulesAsync(student.UserID, cls.ClassID, term.TermID);
        var finding = Assert.Single(findings, f => f.Code == EnrollmentRuleCodes.YearLevelNotSet);
        Assert.False(finding.CanForce);
        Assert.Contains("student year level is not set", finding.Message, StringComparison.OrdinalIgnoreCase);
    }

    // ── 6. Forcing Standing Rule Permissions & Audit ──────────────────────────

    [Fact]
    public async Task StandingRule_ForceByRegistrar_AllowedAndAuditRecorded()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 303", standingYear: 3);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s5",
            Email = "s5@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Alice",
            Lastname = "Smith",
            ProgramID = 1,
            YearLevel = 2
        });
        await _context.SaveChangesAsync();

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = true,
            ForceReason = "Approved by Registrar for graduating deficit"
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _registrarId, callerRole: RoleUtils.Registrar);
        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);

        var load = await _context.StudyLoads.FindAsync(result.StudyLoadId.Value);
        Assert.NotNull(load);
        Assert.True(load.IsForced);
        Assert.Equal(_registrarId, load.ForcedByUserID);
        Assert.Equal("Approved by Registrar for graduating deficit", load.ForcedReason);
    }

    [Fact]
    public async Task StandingRule_ForceByCollegeHead_AllowedAndAuditRecorded()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 304", standingYear: 3);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s6",
            Email = "s6@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Bob",
            Lastname = "Jones",
            ProgramID = 1,
            YearLevel = 2
        });
        await _context.SaveChangesAsync();

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = true,
            ForceReason = "Approved by College Head"
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _collegeHeadId, callerRole: RoleUtils.CollegeHead);
        Assert.True(result.Success);
        Assert.NotNull(result.StudyLoadId);

        var load = await _context.StudyLoads.FindAsync(result.StudyLoadId.Value);
        Assert.NotNull(load);
        Assert.True(load.IsForced);
        Assert.Equal(_collegeHeadId, load.ForcedByUserID);
        Assert.Equal("Approved by College Head", load.ForcedReason);
    }

    [Fact]
    public async Task StandingRule_ForceByTeacher_Rejected()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 305", standingYear: 3);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s7",
            Email = "s7@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Charlie",
            Lastname = "Brown",
            ProgramID = 1,
            YearLevel = 2
        });
        await _context.SaveChangesAsync();

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = true,
            ForceReason = "Teacher attempted override"
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _teacherId, callerRole: RoleUtils.Teacher);
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Contains(result.Warnings, w => w.Contains("Only College Head and Registrar can force enrollment"));
    }

    [Fact]
    public async Task StandingRule_ForceByStudent_Rejected()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 306", standingYear: 3);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s8",
            Email = "s8@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "David",
            Lastname = "Miller",
            ProgramID = 1,
            YearLevel = 2
        });
        await _context.SaveChangesAsync();

        var dto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = true,
            ForceReason = "Self override attempt"
        };

        var result = await _studyLoadService.EnrollSingleAsync(dto, _studentId, callerRole: RoleUtils.Student);
        Assert.False(result.Success);
        Assert.Null(result.StudyLoadId);
        Assert.Contains(result.Warnings, w => w.Contains("Only College Head and Registrar can force enrollment"));
    }

    [Fact]
    public async Task StandingRule_StudentYearLevelNull_CannotBeForcedEvenByRegistrarOrCollegeHead()
    {
        var (subject, cls, term) = await SeedClassWithSubjectAsync("IT 402", standingYear: 4);

        var student = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = "fb-s9",
            Email = "s9@dbtc.edu.ph",
            Role = RoleUtils.Student,
            IsActive = true
        };
        _context.Users.Add(student);
        // No UserDetails or YearLevel is null
        _context.UserDetails.Add(new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = student.UserID,
            Firstname = "Eve",
            Lastname = "White",
            ProgramID = 1,
            YearLevel = null
        });
        await _context.SaveChangesAsync();

        // Registrar attempts to force
        var regDto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = true,
            ForceReason = "Registrar force attempt with missing year level"
        };
        var regResult = await _studyLoadService.EnrollSingleAsync(regDto, _registrarId, callerRole: RoleUtils.Registrar);
        Assert.False(regResult.Success);
        Assert.Null(regResult.StudyLoadId);
        Assert.Contains(regResult.Warnings, w => w.Contains("student year level is not set", StringComparison.OrdinalIgnoreCase));

        // College Head attempts to force
        var chDto = new EnrollSingleRequestDto
        {
            UserId = student.UserID,
            ClassId = cls.ClassID,
            Force = true,
            ForceReason = "College Head force attempt with missing year level"
        };
        var chResult = await _studyLoadService.EnrollSingleAsync(chDto, _collegeHeadId, callerRole: RoleUtils.CollegeHead);
        Assert.False(chResult.Success);
        Assert.Null(chResult.StudyLoadId);
        Assert.Contains(chResult.Warnings, w => w.Contains("student year level is not set", StringComparison.OrdinalIgnoreCase));
    }
}
