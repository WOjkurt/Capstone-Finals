using System.ComponentModel.DataAnnotations;

namespace Api.Domain.IdentityAccess;

public class Position
{
    [Key]
    public Guid PositionID { get; set; }
    public required string PositionName { get; set; }
}
