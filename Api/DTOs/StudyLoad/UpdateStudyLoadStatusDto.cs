using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.StudyLoad;

public class UpdateStudyLoadStatusDto
{
    [Range(1, 3)]
    public int LoadStatus { get; set; }
}
