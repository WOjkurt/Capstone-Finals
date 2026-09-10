using Api.DTOs.Admin;

namespace Api.Services;

public interface IStaffService
{
    Task<StaffResponseDto> CreateStaffAsync(CreateStaffDto dto, Guid adminUserId);
    Task<List<StaffResponseDto>> GetAllStaffAsync();
    Task<StaffResponseDto> DisableStaffAsync(Guid userId, Guid adminUserId);
    Task<StaffResponseDto> ReactivateStaffAsync(Guid userId, Guid adminUserId);
}
