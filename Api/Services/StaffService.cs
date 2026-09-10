using Api.Auth;
using Api.Domain.IdentityAccess;
using Api.DTOs.Admin;
using Api.Repositories;
using FirebaseAdmin.Auth;
using Microsoft.EntityFrameworkCore;

namespace Api.Services;

public class StaffService : IStaffService
{
    private readonly AppDbContext _context;
    private readonly IUserRepository _userRepository;
    private readonly IUserDetailsRepository _userDetailsRepository;
    private readonly IPositionRepository _positionRepository;
    private readonly IAcademicProgramRepository _academicProgramRepository;
    private readonly IConfiguration _configuration;

    public StaffService(
        AppDbContext context,
        IUserRepository userRepository,
        IUserDetailsRepository userDetailsRepository,
        IPositionRepository positionRepository,
        IAcademicProgramRepository academicProgramRepository,
        IConfiguration configuration)
    {
        _context = context;
        _userRepository = userRepository;
        _userDetailsRepository = userDetailsRepository;
        _positionRepository = positionRepository;
        _academicProgramRepository = academicProgramRepository;
        _configuration = configuration;
    }

    public async Task<StaffResponseDto> CreateStaffAsync(CreateStaffDto dto, Guid adminUserId)
    {
        if (dto.Role is RoleUtils.Admin or RoleUtils.Student || !RoleUtils.IsValidRole(dto.Role))
        {
            throw new InvalidOperationException("Invalid role. Only Registrar (2), Teacher (3), or Program Head (4) accounts can be created through staff management.");
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

        if (dto.ProgramID.HasValue)
        {
            var prog = await _academicProgramRepository.GetByIdAsync(dto.ProgramID.Value);
            if (prog == null)
            {
                throw new KeyNotFoundException($"AcademicProgram with ID '{dto.ProgramID.Value}' was not found.");
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
            ProgramID = dto.ProgramID,
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
                Console.WriteLine($"[STAFF COMPENSATION ERROR] Failed to delete Firebase user '{firebaseUser.Uid}' after DB failure: {fbEx.Message}");
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
            Console.WriteLine($"[STAFF WARNING] Could not generate password reset link for '{email}': {ex.Message}");
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
            Console.WriteLine($"[STAFF WARNING] Firebase disable update failed for '{user.FirebaseUID}': {ex.Message}");
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
            Console.WriteLine($"[STAFF WARNING] Firebase reactivate update failed for '{user.FirebaseUID}': {ex.Message}");
            firebaseWarning = "Database updated, but Firebase sync failed \u2014 this may need manual attention";
        }

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
