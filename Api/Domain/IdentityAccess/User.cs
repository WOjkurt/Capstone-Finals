using System.ComponentModel.DataAnnotations;

namespace Api.Domain.IdentityAccess;

public class User
{
    [Key]
    public Guid UserID { get; set; }
    public required string FirebaseUID { get; set; }
    public required string Email { get; set; }
    public int Role { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
}
