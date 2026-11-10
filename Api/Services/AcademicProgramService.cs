using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class AcademicProgramService : IAcademicProgramService
{
    private readonly AppDbContext _context;
    private readonly IAcademicProgramRepository _programRepository;

    public AcademicProgramService(AppDbContext context, IAcademicProgramRepository programRepository)
    {
        _context = context;
        _programRepository = programRepository;
    }

    public async Task<AcademicProgramDto> CreateAsync(CreateAcademicProgramDto dto)
    {
        var program = new AcademicProgram
        {
            ProgramCode = dto.ProgramCode,
            ProgramName = dto.ProgramName,
            Major = CleanMajor(dto.Major)
        };

        await _programRepository.AddAsync(program);

        return new AcademicProgramDto
        {
            ProgramID = program.ProgramID,
            ProgramCode = program.ProgramCode,
            ProgramName = program.ProgramName,
            Major = program.Major
        };
    }

    public async Task<List<AcademicProgramDto>> GetAllAsync()
    {
        var programs = await _programRepository.GetAllAsync();
        return programs.Select(p => new AcademicProgramDto
        {
            ProgramID = p.ProgramID,
            ProgramCode = p.ProgramCode,
            ProgramName = p.ProgramName,
            Major = p.Major
        }).ToList();
    }

    public async Task<AcademicProgramDto?> GetByIdAsync(int programId)
    {
        var program = await _programRepository.GetByIdAsync(programId);
        if (program == null)
        {
            return null;
        }

        return new AcademicProgramDto
        {
            ProgramID = program.ProgramID,
            ProgramCode = program.ProgramCode,
            ProgramName = program.ProgramName,
            Major = program.Major
        };
    }

    public async Task<AcademicProgramDto> UpdateAsync(int programId, CreateAcademicProgramDto dto)
    {
        var program = await _programRepository.GetByIdAsync(programId);
        if (program == null)
        {
            throw new KeyNotFoundException($"AcademicProgram with ID '{programId}' was not found.");
        }

        program.ProgramCode = dto.ProgramCode;
        program.ProgramName = dto.ProgramName;
        program.Major = CleanMajor(dto.Major);

        await _programRepository.UpdateAsync(program);

        return new AcademicProgramDto
        {
            ProgramID = program.ProgramID,
            ProgramCode = program.ProgramCode,
            ProgramName = program.ProgramName,
            Major = program.Major
        };
    }

    /// <summary>"Major in Mechanical Technology" → "Mechanical Technology"; blank → none.</summary>
    public static string? CleanMajor(string? major)
    {
        var m = (major ?? "").Trim();
        if (m.StartsWith("major in ", StringComparison.OrdinalIgnoreCase)) m = m[9..].Trim();
        return m.Length == 0 ? null : m;
    }

    public async Task DeleteAsync(int programId)
    {
        var program = await _programRepository.GetByIdAsync(programId);
        if (program == null)
        {
            throw new KeyNotFoundException($"AcademicProgram with ID '{programId}' was not found.");
        }

        bool hasSubjects = await _context.Subjects.AnyAsync(s => s.ProgramID == programId);
        if (hasSubjects)
        {
            throw new InvalidOperationException($"Cannot delete AcademicProgram '{program.ProgramCode}' because it is referenced by existing subjects.");
        }

        bool hasUserDetails = await _context.UserDetails.AnyAsync(ud => ud.ProgramID == programId);
        if (hasUserDetails)
        {
            throw new InvalidOperationException($"Cannot delete AcademicProgram '{program.ProgramCode}' because it is referenced by existing user details.");
        }

        await _programRepository.DeleteAsync(programId);
    }
}
