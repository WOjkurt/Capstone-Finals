using Api.Common;
using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Api.Repositories;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class AcademicTermService : IAcademicTermService
{
    private readonly AppDbContext _context;
    private readonly IAcademicTermRepository _termRepository;

    public AcademicTermService(AppDbContext context, IAcademicTermRepository termRepository)
    {
        _context = context;
        _termRepository = termRepository;
    }

    public async Task<AcademicTermDto> CreateAsync(CreateAcademicTermDto dto)
    {
        var term = new AcademicTerm
        {
            TermID = Guid.NewGuid(),
            SchoolYear = dto.SchoolYear,
            Semester = dto.Semester
        };

        await _termRepository.AddAsync(term);

        return new AcademicTermDto
        {
            TermID = term.TermID,
            SchoolYear = term.SchoolYear,
            Semester = term.Semester,
            IsActive = term.IsActive
        };
    }

    public async Task<List<AcademicTermDto>> GetAllAsync()
    {
        var terms = await _termRepository.GetAllAsync();
        return terms.Select(t => new AcademicTermDto
        {
            TermID = t.TermID,
            SchoolYear = t.SchoolYear,
            Semester = t.Semester,
            IsActive = t.IsActive
        }).ToList();
    }

    public async Task<AcademicTermDto?> GetByIdAsync(Guid termId)
    {
        var term = await _termRepository.GetByIdAsync(termId);
        if (term == null)
        {
            return null;
        }

        return new AcademicTermDto
        {
            TermID = term.TermID,
            SchoolYear = term.SchoolYear,
            Semester = term.Semester,
            IsActive = term.IsActive
        };
    }

    public async Task<AcademicTermDto?> GetActiveAsync()
    {
        var term = await _termRepository.GetActiveAsync();
        if (term == null)
        {
            return null;
        }

        return new AcademicTermDto
        {
            TermID = term.TermID,
            SchoolYear = term.SchoolYear,
            Semester = term.Semester,
            IsActive = term.IsActive
        };
    }

    public async Task<AcademicTermDto> UpdateAsync(Guid termId, CreateAcademicTermDto dto)
    {
        var term = await _termRepository.GetByIdAsync(termId);
        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }

        term.SchoolYear = dto.SchoolYear;
        term.Semester = dto.Semester;

        await _termRepository.UpdateAsync(term);

        return new AcademicTermDto
        {
            TermID = term.TermID,
            SchoolYear = term.SchoolYear,
            Semester = term.Semester,
            IsActive = term.IsActive
        };
    }

    public async Task<AcademicTermDto> ActivateAsync(Guid termId)
    {
        var term = await _termRepository.GetByIdAsync(termId);
        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }

        await _termRepository.SetActiveAsync(termId);

        return new AcademicTermDto
        {
            TermID = term.TermID,
            SchoolYear = term.SchoolYear,
            Semester = term.Semester,
            IsActive = true
        };
    }

    public async Task DeleteAsync(Guid termId)
    {
        var term = await _termRepository.GetByIdAsync(termId);
        if (term == null)
        {
            throw new KeyNotFoundException($"AcademicTerm with ID '{termId}' was not found.");
        }

        bool hasClasses = await _context.Classes.AnyAsync(c => c.TermID == termId);
        if (hasClasses)
        {
            throw new InvalidOperationException($"Cannot delete AcademicTerm '{TermLabel.Format(term.SchoolYear, term.Semester)}' because it is referenced by existing classes.");
        }

        bool hasApplications = await _context.EnrollmentApplications.AnyAsync(ea => ea.TermID == termId);
        if (hasApplications)
        {
            throw new InvalidOperationException($"Cannot delete AcademicTerm '{TermLabel.Format(term.SchoolYear, term.Semester)}' because it is referenced by existing enrollment applications.");
        }

        await _termRepository.DeleteAsync(termId);
    }
}
