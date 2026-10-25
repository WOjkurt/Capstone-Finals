namespace Api.DTOs.Curriculum;

public class CurriculumImportResponseDto
{
    public bool DryRun { get; set; }
    public string Program { get; set; } = string.Empty;
    public SubjectCountsDto Subjects { get; set; } = new();
    public RequisiteCountsDto Requisites { get; set; } = new();
    public List<CurriculumImportFindingDto> Warnings { get; set; } = new();
    public List<CurriculumImportFindingDto> Errors { get; set; } = new();
    public int TotalWarnings { get; set; }
    public int TotalErrors { get; set; }
}

public class SubjectCountsDto
{
    public int Create { get; set; }
    public int Update { get; set; }
    public int Unchanged { get; set; }
}

public class RequisiteCountsDto
{
    public int PrerequisitesToAdd { get; set; }
    public int CorequisitesToAdd { get; set; }
    public int AlreadyExist { get; set; }
    public int ExtrasInDatabase { get; set; }
}

public class CurriculumImportFindingDto
{
    public int Row { get; set; }
    public string Code { get; set; } = string.Empty;
    public string Message { get; set; } = string.Empty;
}
