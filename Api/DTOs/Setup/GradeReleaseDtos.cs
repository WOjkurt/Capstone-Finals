namespace Api.DTOs.Setup;

/// <summary>Whether a class's grade sheet has been checked.</summary>
public class SetVerificationDto
{
    public bool Verified { get; set; }
}

/// <summary>Whether a term's grades may be seen by students at all.</summary>
public class SetGradeReleaseDto
{
    public bool Released { get; set; }
}
