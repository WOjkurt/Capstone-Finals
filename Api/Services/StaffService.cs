using Api.Auth;
using Api.Domain.IdentityAccess;
using Api.DTOs.Admin;
using Api.Repositories;
using FirebaseAdmin.Auth;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Api.Services;

public class StaffService : IStaffService
{
    private readonly AppDbContext _context;
    private readonly IUserRepository _userRepository;
    private readonly IUserDetailsRepository _userDetailsRepository;
    private readonly IPositionRepository _positionRepository;
    private readonly IAcademicProgramRepository _academicProgramRepository;
    private readonly IConfiguration _configuration;
    private readonly ILogger<StaffService> _logger;

    public StaffService(
        AppDbContext context,
        IUserRepository userRepository,
        IUserDetailsRepository userDetailsRepository,
        IPositionRepository positionRepository,
        IAcademicProgramRepository academicProgramRepository,
        IConfiguration configuration,
        ILogger<StaffService> logger)
    {
        _context = context;
        _userRepository = userRepository;
        _userDetailsRepository = userDetailsRepository;
        _positionRepository = positionRepository;
        _academicProgramRepository = academicProgramRepository;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<StaffResponseDto> CreateStaffAsync(CreateStaffDto dto, Guid adminUserId)
    {
        if (dto.Role is RoleUtils.Admin or RoleUtils.Student || !RoleUtils.IsValidRole(dto.Role))
        {
            throw new InvalidOperationException("Invalid role. Only Registrar (2), Teacher (3), Program Head (4), or College Head (6) accounts can be created through staff management.");
        }

        var email = dto.Email.Trim().ToLowerInvariant();
        var allowedDomain = _configuration["Auth:AllowedEmailDomain"] ?? "@dbtc-cebu.edu.ph";
        if (!email.EndsWith(allowedDomain, StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException($"Only email addresses ending with '{allowedDomain}' are allowed.");
        }

        var existingUser = await _userRepository.GetByEmailAsync(email);
        if (existingUser != null)
        {
            throw new InvalidOperationException($"An account with email '{email}' already exists.");
        }

        if (dto.PositionID.HasValue)
        {
            var pos = await _positionRepository.GetByIdAsync(dto.PositionID.Value);
            if (pos == null)
            {
                throw new KeyNotFoundException($"Position with ID '{dto.PositionID.Value}' was not found.");
            }
        }

        int? effectiveProgramId = dto.Role == RoleUtils.CollegeHead ? null : dto.ProgramID;
        if (effectiveProgramId.HasValue)
        {
            var prog = await _academicProgramRepository.GetByIdAsync(effectiveProgramId.Value);
            if (prog == null)
            {
                throw new KeyNotFoundException($"AcademicProgram with ID '{effectiveProgramId.Value}' was not found.");
            }
        }

        UserRecord firebaseUser;
        try
        {
            firebaseUser = await FirebaseAuth.DefaultInstance.CreateUserAsync(new UserRecordArgs
            {
                Email = email,
                EmailVerified = true,
                Disabled = false,
                DisplayName = $"{dto.Firstname.Trim()} {dto.Lastname.Trim()}"
            });
        }
        catch (FirebaseAuthException ex)
        {
            throw new InvalidOperationException($"Failed to create Firebase user: {ex.Message}");
        }

        var user = new User
        {
            UserID = Guid.NewGuid(),
            FirebaseUID = firebaseUser.Uid,
            Email = email,
            Role = dto.Role,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        var userDetails = new UserDetails
        {
            UserDetailID = Guid.NewGuid(),
            UserID = user.UserID,
            Firstname = dto.Firstname.Trim(),
            Lastname = dto.Lastname.Trim(),
            EmployeeID = dto.EmployeeID,
            PositionID = dto.PositionID,
            ProgramID = effectiveProgramId,
            IsRegular = dto.IsRegular ?? true
        };

        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            await _userRepository.AddAsync(user);
            await _userDetailsRepository.AddAsync(userDetails);
            await transaction.CommitAsync();
        }
        catch (Exception dbEx)
        {
            await transaction.RollbackAsync();

            // Compensation: Delete created Firebase user so we don't leave orphaned accounts
            try
            {
                await FirebaseAuth.DefaultInstance.DeleteUserAsync(firebaseUser.Uid);
            }
            catch (Exception fbEx)
            {
                _logger.LogError(fbEx, "Compensation failed: could not delete orphaned Firebase account after DB rollback. FirebaseUID={FirebaseUID}", firebaseUser.Uid);
            }

            throw new InvalidOperationException($"Failed to save staff record: {dbEx.Message}");
        }

        string? passwordResetLink = null;
        try
        {
            passwordResetLink = await FirebaseAuth.DefaultInstance.GeneratePasswordResetLinkAsync(email);
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Could not generate password reset link for new staff account.");
        }

        return await BuildStaffResponseDto(user.UserID, passwordResetLink);
    }

    public async Task<List<StaffResponseDto>> GetAllStaffAsync()
    {
        var staffUsers = await _context.Users
            .Where(u => u.Role != RoleUtils.Student)
            .OrderByDescending(u => u.CreatedAt)
            .ToListAsync();

        var userIds = staffUsers.Select(u => u.UserID).ToList();

        var detailsList = await _context.UserDetails
            .Include(ud => ud.Position)
            .Include(ud => ud.Program)
            .Where(ud => userIds.Contains(ud.UserID))
            .ToListAsync();

        var detailsMap = detailsList.ToDictionary(ud => ud.UserID);

        return staffUsers.Select(u =>
        {
            detailsMap.TryGetValue(u.UserID, out var details);
            return new StaffResponseDto
            {
                UserID = u.UserID,
                FirebaseUID = u.FirebaseUID,
                Email = u.Email,
                Role = u.Role,
                RoleName = RoleUtils.GetRoleName(u.Role),
                Firstname = details?.Firstname ?? string.Empty,
                Lastname = details?.Lastname ?? string.Empty,
                EmployeeID = details?.EmployeeID,
                PositionID = details?.PositionID,
                PositionName = details?.Position?.PositionName,
                ProgramID = details?.ProgramID,
                ProgramCode = details?.Program?.ProgramCode,
                IsRegular = details?.IsRegular ?? true,
                IsActive = u.IsActive,
                CreatedAt = u.CreatedAt
            };
        }).ToList();
    }

    public async Task<StaffResponseDto> DisableStaffAsync(Guid userId, Guid adminUserId)
    {
        var user = await _userRepository.GetByIdAsync(userId);
        if (user == null)
        {
            throw new KeyNotFoundException($"Staff user with ID '{userId}' was not found.");
        }

        if (user.UserID == adminUserId)
        {
            throw new InvalidOperationException("You cannot disable your own admin account.");
        }

        if (user.Role == RoleUtils.Admin)
        {
            throw new InvalidOperationException("Admin accounts cannot be disabled through staff management.");
        }

        user.IsActive = false;
        await _userRepository.UpdateAsync(user);

        string? firebaseWarning = null;
        try
        {
            await FirebaseAuth.DefaultInstance.UpdateUserAsync(new UserRecordArgs
            {
                Uid = user.FirebaseUID,
                Disabled = true
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Firebase disable sync failed for UserID={UserID}. DB is updated; manual Firebase remediation may be needed.", user.UserID);
            firebaseWarning = "Database updated, but Firebase sync failed \u2014 this may need manual attention";
        }

        return await BuildStaffResponseDto(user.UserID, firebaseSyncWarning: firebaseWarning);
    }

    public async Task<StaffResponseDto> ReactivateStaffAsync(Guid userId, Guid adminUserId)
    {
        var user = await _userRepository.GetByIdAsync(userId);
        if (user == null)
        {
            throw new KeyNotFoundException($"Staff user with ID '{userId}' was not found.");
        }

        user.IsActive = true;
        await _userRepository.UpdateAsync(user);

        string? firebaseWarning = null;
        try
        {
            await FirebaseAuth.DefaultInstance.UpdateUserAsync(new UserRecordArgs
            {
                Uid = user.FirebaseUID,
                Disabled = false
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Firebase reactivate sync failed for UserID={UserID}. DB is updated; manual Firebase remediation may be needed.", user.UserID);
            firebaseWarning = "Database updated, but Firebase sync failed \u2014 this may need manual attention";
        }

        return await BuildStaffResponseDto(user.UserID, firebaseSyncWarning: firebaseWarning);
    }

    public async Task<StaffResponseDto> UpdateStaffAsync(Guid userId, UpdateStaffDto dto, Guid adminUserId)
    {
        var user = await _userRepository.GetByIdAsync(userId);
        if (user == null)
        {
            throw new KeyNotFoundException($"Staff user with ID '{userId}' was not found.");
        }

        var userDetails = await _context.UserDetails
            .Include(ud => ud.Position)
            .Include(ud => ud.Program)
            .FirstOrDefaultAsync(ud => ud.UserID == userId);
        if (userDetails == null)
        {
            throw new KeyNotFoundException($"Staff details for user ID '{userId}' were not found.");
        }

        // Self and Admin protections:
        if (user.UserID == adminUserId && dto.Role.HasValue && dto.Role.Value != user.Role)
        {
            throw new InvalidOperationException("You cannot change your own admin account role.");
        }

        if (user.Role == RoleUtils.Admin)
        {
            throw new InvalidOperationException("Admin accounts cannot be modified through staff management.");
        }

        // Role validation if provided
        int effectiveRole = user.Role;
        if (dto.Role.HasValue)
        {
            if (dto.Role.Value is RoleUtils.Admin or RoleUtils.Student || !RoleUtils.IsValidRole(dto.Role.Value))
            {
                throw new InvalidOperationException("Invalid role. Only Registrar (2), Teacher (3), Program Head (4), or College Head (6) roles can be assigned.");
            }
            effectiveRole = dto.Role.Value;
        }

        // Position validation if provided
        if (dto.PositionID.HasValue)
        {
            if (dto.PositionID.Value == Guid.Empty)
            {
                userDetails.PositionID = null;
            }
            else
            {
                var pos = await _positionRepository.GetByIdAsync(dto.PositionID.Value);
                if (pos == null)
                {
                    throw new KeyNotFoundException($"Position with ID '{dto.PositionID.Value}' was not found.");
                }
                userDetails.PositionID = dto.PositionID.Value;
            }
        }

        // Program validation and role-specific program scoping rules
        if (dto.ProgramID.HasValue && dto.ProgramID.Value > 0)
        {
            var prog = await _academicProgramRepository.GetByIdAsync(dto.ProgramID.Value);
            if (prog == null)
            {
                throw new KeyNotFoundException($"AcademicProgram with ID '{dto.ProgramID.Value}' was not found.");
            }
        }

        if (effectiveRole == RoleUtils.ProgramHead)
        {
            // Program Head requires ProgramID
            var targetProgramId = dto.ProgramID.HasValue
                ? (dto.ProgramID.Value > 0 ? dto.ProgramID.Value : (int?)null)
                : (user.Role == RoleUtils.CollegeHead ? (int?)null : userDetails.ProgramID);
            if (!targetProgramId.HasValue || targetProgramId.Value <= 0)
            {
                throw new InvalidOperationException("Academic program is required for Program Head accounts.");
            }
            userDetails.ProgramID = targetProgramId.Value;
        }
        else if (effectiveRole == RoleUtils.Registrar || effectiveRole == RoleUtils.CollegeHead)
        {
            // Registrar and College Head force ProgramID to null
            userDetails.ProgramID = null;
        }
        else if (effectiveRole == RoleUtils.Teacher)
        {
            // Teacher / Program Head -> Teacher preserves existing ProgramID unless explicitly changed
            if (dto.ProgramID.HasValue)
            {
                if (dto.ProgramID.Value <= 0)
                {
                    userDetails.ProgramID = null;
                }
                else
                {
                    userDetails.ProgramID = dto.ProgramID.Value;
                }
            }
        }

        if (dto.EmployeeID.HasValue)
        {
            userDetails.EmployeeID = dto.EmployeeID.Value <= 0 ? null : dto.EmployeeID.Value;
        }

        if (dto.IsRegular.HasValue)
        {
            userDetails.IsRegular = dto.IsRegular.Value;
        }

        // Firstname and Lastname updates + Firebase DisplayName sync
        bool nameChanged = false;
        if (dto.Firstname != null && !string.IsNullOrWhiteSpace(dto.Firstname) && dto.Firstname.Trim() != userDetails.Firstname)
        {
            userDetails.Firstname = dto.Firstname.Trim();
            nameChanged = true;
        }
        if (dto.Lastname != null && !string.IsNullOrWhiteSpace(dto.Lastname) && dto.Lastname.Trim() != userDetails.Lastname)
        {
            userDetails.Lastname = dto.Lastname.Trim();
            nameChanged = true;
        }

        string? firebaseWarning = null;
        if (nameChanged)
        {
            try
            {
                await FirebaseAuth.DefaultInstance.UpdateUserAsync(new UserRecordArgs
                {
                    Uid = user.FirebaseUID,
                    DisplayName = $"{userDetails.Firstname} {userDetails.Lastname}"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Firebase display name sync failed for UserID={UserID}. DB is updated; manual Firebase remediation may be needed.", user.UserID);
                firebaseWarning = "Database updated, but Firebase sync failed \u2014 this may need manual attention";
            }
        }

        // Active-classes advisory warning (not a block) when moving away from a teaching role
        bool wasTeachingRole = user.Role is RoleUtils.Teacher or RoleUtils.ProgramHead;
        bool isMovingAwayFromTeaching = wasTeachingRole && (effectiveRole == RoleUtils.Registrar || effectiveRole == RoleUtils.CollegeHead);
        if (isMovingAwayFromTeaching)
        {
            var assignedClassCount = await _context.Classes.CountAsync(c => c.UserID == user.UserID);
            if (assignedClassCount > 0)
            {
                var classWarning = $"Note: This staff member is still assigned as instructor to {assignedClassCount} class(es). Reassign active offerings in Class Management.";
                firebaseWarning = string.IsNullOrEmpty(firebaseWarning)
                    ? classWarning
                    : $"{firebaseWarning}; {classWarning}";
            }
        }

        user.Role = effectiveRole;
        await _userRepository.UpdateAsync(user);
        await _userDetailsRepository.UpdateAsync(userDetails);

        return await BuildStaffResponseDto(user.UserID, firebaseSyncWarning: firebaseWarning);
    }

    private async Task<StaffResponseDto> BuildStaffResponseDto(
        Guid userId,
        string? passwordResetLink = null,
        string? firebaseSyncWarning = null)
    {
        var user = await _userRepository.GetByIdAsync(userId);
        if (user == null)
        {
            throw new KeyNotFoundException($"User with ID '{userId}' was not found.");
        }

        var details = await _context.UserDetails
            .Include(ud => ud.Position)
            .Include(ud => ud.Program)
            .FirstOrDefaultAsync(ud => ud.UserID == userId);

        return new StaffResponseDto
        {
            UserID = user.UserID,
            FirebaseUID = user.FirebaseUID,
            Email = user.Email,
            Role = user.Role,
            RoleName = RoleUtils.GetRoleName(user.Role),
            Firstname = details?.Firstname ?? string.Empty,
            Lastname = details?.Lastname ?? string.Empty,
            EmployeeID = details?.EmployeeID,
            PositionID = details?.PositionID,
            PositionName = details?.Position?.PositionName,
            ProgramID = details?.ProgramID,
            ProgramCode = details?.Program?.ProgramCode,
            IsRegular = details?.IsRegular ?? true,
            IsActive = user.IsActive,
            CreatedAt = user.CreatedAt,
            PasswordResetLink = passwordResetLink,
            FirebaseSyncWarning = firebaseSyncWarning
        };
    }
}
