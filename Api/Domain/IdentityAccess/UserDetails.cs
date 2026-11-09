using System.ComponentModel.DataAnnotations;
using Api.Domain.Enrollment;

namespace Api.Domain.IdentityAccess;

public class UserDetails
{
    [Key]
    public Guid UserDetailID { get; set; }

    public Guid UserID { get; set; }
    public User? User { get; set; }

    public required string Firstname { get; set; }
    public required string Lastname { get; set; }

    public string? LRN { get; set; }

    /// <summary>For students: the DBTC student ID (digits, e.g. 25060208). Empty until the school assigns one.</summary>
    [MaxLength(20)]
    public string? StudentID { get; set; }

    public int? ProgramID { get; set; }
    public AcademicProgram? Program { get; set; }

    /// <summary>For students: the curriculum they follow. Empty means "all subjects of the program" (old records).</summary>
    public Guid? CurriculumID { get; set; }
    public Curriculum? Curriculum { get; set; }

    public int? StudentType { get; set; }
    public int? StudentStatus { get; set; }
    public int? YearLevel { get; set; }

    public int? EmployeeID { get; set; }

    public Guid? PositionID { get; set; }
    public Position? Position { get; set; }

    public bool IsRegular { get; set; } = true;

    /// <summary>
    /// For students: when they were marked irregular. Back major subjects passed since then count toward
    /// becoming regular again (6 units). Empty while regular.
    /// </summary>
    public DateTime? IrregularSince { get; set; }
}
