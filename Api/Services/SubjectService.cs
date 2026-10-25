using Api.Constants;
using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class SubjectService : ISubjectService
{
    private readonly AppDbContext _context;
    private readonly ISubjectRepository _subjectRepository;
    private readonly ISubjectPrerequisiteRepository _prerequisiteRepository;
    private readonly IAcademicProgramRepository _programRepository;

    public SubjectService(
        AppDbContext context,
        ISubjectRepository subjectRepository,
        ISubjectPrerequisiteRepository prerequisiteRepository,
        IAcademicProgramRepository programRepository)
    {
        _context = context;
        _subjectRepository = subjectRepository;
        _prerequisiteRepository = prerequisiteRepository;
        _programRepository = programRepository;
    }

    public async Task<SubjectDto> CreateAsync(CreateSubjectDto dto)
    {
        var program = await _programRepository.GetByIdAsync(dto.ProgramID);
        if (program == null)
        {
            throw new KeyNotFoundException($"AcademicProgram with ID '{dto.ProgramID}' was not found.");
        }

        if (dto.StandingYear.HasValue && (dto.StandingYear.Value < 1 || dto.StandingYear.Value > 4))
        {
            throw new ArgumentException("StandingYear must be between 1 and 4.", nameof(dto.StandingYear));
        }

        var normalizedCode = NormalizeSubjectCode(dto.SubjectCode);
        if (string.IsNullOrWhiteSpace(normalizedCode))
        {
            throw new ArgumentException("SubjectCode cannot be empty.", nameof(dto.SubjectCode));
        }

        var duplicateExists = await _context.Subjects
            .AnyAsync(s => s.ProgramID == dto.ProgramID && s.SubjectCode == normalizedCode);
        if (duplicateExists)
        {
            throw new DuplicateSubjectCodeException(normalizedCode, program.ProgramCode);
        }

        var subject = new Subject
        {
            SubjectID = Guid.NewGuid(),
            SubjectCode = normalizedCode,
            SubjectTitle = dto.SubjectTitle,
            LecUnits = dto.LecUnits,
            LabUnits = dto.LabUnits,
            LecHours = dto.LecHours,
            LabHours = dto.LabHours,
            ProgramID = dto.ProgramID,
            YearLevel = dto.YearLevel,
            DefaultSemester = dto.DefaultSemester,
            StandingYear = dto.StandingYear
        };

        await _subjectRepository.AddAsync(subject);

        return new SubjectDto
        {
            SubjectID = subject.SubjectID,
            SubjectCode = subject.SubjectCode,
            SubjectTitle = subject.SubjectTitle,
            LecUnits = subject.LecUnits,
            LabUnits = subject.LabUnits,
            LecHours = subject.LecHours,
            LabHours = subject.LabHours,
            ProgramID = subject.ProgramID,
            ProgramCode = program.ProgramCode,
            YearLevel = subject.YearLevel,
            DefaultSemester = subject.DefaultSemester,
            StandingYear = subject.StandingYear,
            Prerequisites = new List<PrerequisiteDto>()
        };
    }

    private static string NormalizeSubjectCode(string? code)
    {
        if (string.IsNullOrWhiteSpace(code)) return string.Empty;
        return System.Text.RegularExpressions.Regex.Replace(code.Trim(), @"\s+", " ").ToUpperInvariant();
    }

    public async Task<List<SubjectDto>> GetAllAsync(int? programId = null, int? yearLevel = null)
    {
        var query = _context.Subjects
            .Include(s => s.Program)
            .AsQueryable();

        if (programId.HasValue)
        {
            query = query.Where(s => s.ProgramID == programId.Value);
        }

        if (yearLevel.HasValue)
        {
            query = query.Where(s => s.YearLevel == yearLevel.Value);
        }

        var subjects = await query.ToListAsync();
        var allPrereqs = await _context.SubjectPrerequisites
            .Include(sp => sp.PrerequisiteSubject)
            .ToListAsync();

        var prereqMap = allPrereqs
            .GroupBy(sp => sp.SubjectID)
            .ToDictionary(g => g.Key, g => g.ToList());

        return subjects.Select(s => new SubjectDto
        {
            SubjectID = s.SubjectID,
            SubjectCode = s.SubjectCode,
            SubjectTitle = s.SubjectTitle,
            LecUnits = s.LecUnits,
            LabUnits = s.LabUnits,
            LecHours = s.LecHours,
            LabHours = s.LabHours,
            ProgramID = s.ProgramID,
            ProgramCode = s.Program?.ProgramCode,
            YearLevel = s.YearLevel,
            DefaultSemester = s.DefaultSemester,
            StandingYear = s.StandingYear,
            Prerequisites = prereqMap.TryGetValue(s.SubjectID, out var prereqs)
                ? prereqs.Select(sp => new PrerequisiteDto
                {
                    PrerequisiteID = sp.PrerequisiteID,
                    SubjectID = sp.SubjectID,
                    PrerequisiteSubjectID = sp.PrerequisiteSubjectID,
                    PrerequisiteSubjectCode = sp.PrerequisiteSubject?.SubjectCode,
                    PrerequisiteSubjectTitle = sp.PrerequisiteSubject?.SubjectTitle,
                    RequisiteType = sp.RequisiteType
                }).ToList()
                : new List<PrerequisiteDto>()
        }).ToList();
    }

    public async Task<SubjectDto?> GetByIdAsync(Guid subjectId)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId);
        if (subject == null)
        {
            return null;
        }

        var prereqs = await _prerequisiteRepository.GetBySubjectIdAsync(subjectId);

        return new SubjectDto
        {
            SubjectID = subject.SubjectID,
            SubjectCode = subject.SubjectCode,
            SubjectTitle = subject.SubjectTitle,
            LecUnits = subject.LecUnits,
            LabUnits = subject.LabUnits,
            LecHours = subject.LecHours,
            LabHours = subject.LabHours,
            ProgramID = subject.ProgramID,
            ProgramCode = subject.Program?.ProgramCode,
            YearLevel = subject.YearLevel,
            DefaultSemester = subject.DefaultSemester,
            StandingYear = subject.StandingYear,
            Prerequisites = prereqs.Select(sp => new PrerequisiteDto
            {
                PrerequisiteID = sp.PrerequisiteID,
                SubjectID = sp.SubjectID,
                PrerequisiteSubjectID = sp.PrerequisiteSubjectID,
                PrerequisiteSubjectCode = sp.PrerequisiteSubject?.SubjectCode,
                PrerequisiteSubjectTitle = sp.PrerequisiteSubject?.SubjectTitle,
                RequisiteType = sp.RequisiteType
            }).ToList()
        };
    }

    public async Task<SubjectDto> UpdateAsync(Guid subjectId, CreateSubjectDto dto)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId);
        if (subject == null)
        {
            throw new KeyNotFoundException($"Subject with ID '{subjectId}' was not found.");
        }

        var program = await _programRepository.GetByIdAsync(dto.ProgramID);
        if (program == null)
        {
            throw new KeyNotFoundException($"AcademicProgram with ID '{dto.ProgramID}' was not found.");
        }

        if (dto.StandingYear.HasValue && (dto.StandingYear.Value < 1 || dto.StandingYear.Value > 4))
        {
            throw new ArgumentException("StandingYear must be between 1 and 4.", nameof(dto.StandingYear));
        }

        var normalizedCode = NormalizeSubjectCode(dto.SubjectCode);
        if (string.IsNullOrWhiteSpace(normalizedCode))
        {
            throw new ArgumentException("SubjectCode cannot be empty.", nameof(dto.SubjectCode));
        }

        var duplicateExists = await _context.Subjects
            .AnyAsync(s => s.SubjectID != subjectId && s.ProgramID == dto.ProgramID && s.SubjectCode == normalizedCode);
        if (duplicateExists)
        {
            throw new DuplicateSubjectCodeException(normalizedCode, program.ProgramCode);
        }

        subject.SubjectCode = normalizedCode;
        subject.SubjectTitle = dto.SubjectTitle;
        subject.LecUnits = dto.LecUnits;
        subject.LabUnits = dto.LabUnits;
        subject.LecHours = dto.LecHours;
        subject.LabHours = dto.LabHours;
        subject.ProgramID = dto.ProgramID;
        subject.YearLevel = dto.YearLevel;
        subject.DefaultSemester = dto.DefaultSemester;
        subject.StandingYear = dto.StandingYear;

        await _subjectRepository.UpdateAsync(subject);

        var prereqs = await _prerequisiteRepository.GetBySubjectIdAsync(subjectId);

        return new SubjectDto
        {
            SubjectID = subject.SubjectID,
            SubjectCode = subject.SubjectCode,
            SubjectTitle = subject.SubjectTitle,
            LecUnits = subject.LecUnits,
            LabUnits = subject.LabUnits,
            LecHours = subject.LecHours,
            LabHours = subject.LabHours,
            ProgramID = subject.ProgramID,
            ProgramCode = program.ProgramCode,
            YearLevel = subject.YearLevel,
            DefaultSemester = subject.DefaultSemester,
            StandingYear = subject.StandingYear,
            Prerequisites = prereqs.Select(sp => new PrerequisiteDto
            {
                PrerequisiteID = sp.PrerequisiteID,
                SubjectID = sp.SubjectID,
                PrerequisiteSubjectID = sp.PrerequisiteSubjectID,
                PrerequisiteSubjectCode = sp.PrerequisiteSubject?.SubjectCode,
                PrerequisiteSubjectTitle = sp.PrerequisiteSubject?.SubjectTitle,
                RequisiteType = sp.RequisiteType
            }).ToList()
        };
    }

    public async Task DeleteAsync(Guid subjectId)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId);
        if (subject == null)
        {
            throw new KeyNotFoundException($"Subject with ID '{subjectId}' was not found.");
        }

        bool hasClasses = await _context.Classes.AnyAsync(c => c.SubjectID == subjectId);
        if (hasClasses)
        {
            throw new InvalidOperationException($"Cannot delete Subject '{subject.SubjectCode}' because it is referenced by existing classes.");
        }

        bool hasStudyLoads = await _context.StudyLoads.AnyAsync(sl => sl.Class != null && sl.Class.SubjectID == subjectId);
        if (hasStudyLoads)
        {
            throw new InvalidOperationException($"Cannot delete Subject '{subject.SubjectCode}' because it is referenced by existing study loads.");
        }

        bool isPrerequisiteOrHasPrerequisites = await _context.SubjectPrerequisites
            .AnyAsync(sp => sp.SubjectID == subjectId || sp.PrerequisiteSubjectID == subjectId);
        if (isPrerequisiteOrHasPrerequisites)
        {
            throw new InvalidOperationException($"Cannot delete Subject '{subject.SubjectCode}' because it is linked in prerequisite relationships.");
        }

        await _subjectRepository.DeleteAsync(subjectId);
    }

    public async Task<PrerequisiteDto> AddPrerequisiteAsync(CreatePrerequisiteDto dto)
    {
        // ── 1. Self-link guard (applies to both types) ────────────────────────
        if (dto.SubjectID == dto.PrerequisiteSubjectID)
        {
            throw new InvalidOperationException("A subject cannot be linked to itself.");
        }

        var subject = await _subjectRepository.GetByIdAsync(dto.SubjectID);
        if (subject == null)
        {
            throw new KeyNotFoundException($"Target subject with ID '{dto.SubjectID}' was not found.");
        }

        var prereqSubject = await _subjectRepository.GetByIdAsync(dto.PrerequisiteSubjectID);
        if (prereqSubject == null)
        {
            throw new KeyNotFoundException($"Prerequisite subject with ID '{dto.PrerequisiteSubjectID}' was not found.");
        }

        // ── 2. Exact-duplicate guard: same pair AND same type ─────────────────
        bool exactDuplicate = await _context.SubjectPrerequisites
            .AnyAsync(sp =>
                sp.SubjectID == dto.SubjectID &&
                sp.PrerequisiteSubjectID == dto.PrerequisiteSubjectID &&
                sp.RequisiteType == dto.RequisiteType);
        if (exactDuplicate)
        {
            var typeLabel = dto.RequisiteType == RequisiteTypeConstants.Prerequisite
                ? "prerequisite"
                : "corequisite";
            throw new InvalidOperationException(
                $"A {typeLabel} relationship already exists between '{subject.SubjectCode}' and '{prereqSubject.SubjectCode}'.");
        }

        // ── 3. Pair-conflict guard: same pair but opposite type ───────────────
        bool oppositeExists = await _context.SubjectPrerequisites
            .AnyAsync(sp =>
                sp.SubjectID == dto.SubjectID &&
                sp.PrerequisiteSubjectID == dto.PrerequisiteSubjectID &&
                sp.RequisiteType != dto.RequisiteType);
        if (oppositeExists)
        {
            var existingTypeLabel = dto.RequisiteType == RequisiteTypeConstants.Prerequisite
                ? "corequisite"
                : "prerequisite";
            var newTypeLabel = dto.RequisiteType == RequisiteTypeConstants.Prerequisite
                ? "prerequisite"
                : "corequisite";
            throw new InvalidOperationException(
                $"Cannot add '{subject.SubjectCode}' → '{prereqSubject.SubjectCode}' as a {newTypeLabel}: " +
                $"that pair already exists as a {existingTypeLabel}. Remove the existing row first.");
        }

        // ── 4. Circular-link guard: only for prerequisites (type 0) ──────────
        //    Mutual corequisites (A coreq B and B coreq A) are explicitly allowed.
        if (dto.RequisiteType == RequisiteTypeConstants.Prerequisite)
        {
            bool circular = await IsReachableViaPrerequisitesAsync(dto.PrerequisiteSubjectID, dto.SubjectID);
            if (circular)
            {
                throw new InvalidOperationException(
                    $"Circular prerequisite detected: '{prereqSubject.SubjectCode}' already requires '{subject.SubjectCode}' directly or indirectly.");
            }
        }

        var prerequisite = new SubjectPrerequisite
        {
            PrerequisiteID = Guid.NewGuid(),
            SubjectID = dto.SubjectID,
            PrerequisiteSubjectID = dto.PrerequisiteSubjectID,
            RequisiteType = dto.RequisiteType
        };

        await _prerequisiteRepository.AddAsync(prerequisite);

        return new PrerequisiteDto
        {
            PrerequisiteID = prerequisite.PrerequisiteID,
            SubjectID = prerequisite.SubjectID,
            PrerequisiteSubjectID = prerequisite.PrerequisiteSubjectID,
            PrerequisiteSubjectCode = prereqSubject.SubjectCode,
            PrerequisiteSubjectTitle = prereqSubject.SubjectTitle,
            RequisiteType = prerequisite.RequisiteType
        };
    }

    public async Task RemovePrerequisiteAsync(Guid prerequisiteId)
    {
        var prerequisite = await _prerequisiteRepository.GetByIdAsync(prerequisiteId);
        if (prerequisite == null)
        {
            throw new KeyNotFoundException($"Prerequisite with ID '{prerequisiteId}' was not found.");
        }

        await _prerequisiteRepository.DeleteAsync(prerequisiteId);
    }

    public async Task<List<PrerequisiteDto>> GetPrerequisitesForSubjectAsync(Guid subjectId)
    {
        var subject = await _subjectRepository.GetByIdAsync(subjectId);
        if (subject == null)
        {
            throw new KeyNotFoundException($"Subject with ID '{subjectId}' was not found.");
        }

        var prereqs = await _prerequisiteRepository.GetBySubjectIdAsync(subjectId);
        return prereqs.Select(sp => new PrerequisiteDto
        {
            PrerequisiteID = sp.PrerequisiteID,
            SubjectID = sp.SubjectID,
            PrerequisiteSubjectID = sp.PrerequisiteSubjectID,
            PrerequisiteSubjectCode = sp.PrerequisiteSubject?.SubjectCode,
            PrerequisiteSubjectTitle = sp.PrerequisiteSubject?.SubjectTitle,
            RequisiteType = sp.RequisiteType
        }).ToList();
    }

    /// <summary>
    /// BFS that only follows RequisiteType == Prerequisite (type 0) edges.
    /// Returns true if <paramref name="targetSubjectId"/> is reachable from
    /// <paramref name="startSubjectId"/> through the prerequisite graph.
    /// </summary>
    private async Task<bool> IsReachableViaPrerequisitesAsync(Guid startSubjectId, Guid targetSubjectId)
    {
        var visited = new HashSet<Guid>();
        var queue = new Queue<Guid>();

        queue.Enqueue(startSubjectId);
        visited.Add(startSubjectId);

        while (queue.Count > 0)
        {
            var current = queue.Dequeue();

            if (current == targetSubjectId)
            {
                return true;
            }

            var prereqsOfCurrent = await _context.SubjectPrerequisites
                .Where(sp => sp.SubjectID == current && sp.RequisiteType == RequisiteTypeConstants.Prerequisite)
                .Select(sp => sp.PrerequisiteSubjectID)
                .ToListAsync();

            foreach (var next in prereqsOfCurrent)
            {
                if (visited.Add(next))
                {
                    queue.Enqueue(next);
                }
            }
        }

        return false;
    }
}
