using Api.Auth;

namespace Api.DTOs.StudyLoad;

public static class ForceAuditMaskingHelper
{
    /// <summary>
    /// Determines whether the specified caller role is authorized to view
    /// force-enrollment audit fields (IsForced, ForcedByUserID, ForcedReason).
    /// Allowed roles: Registrar, Admin, Program Head, College Head.
    /// Note: College Head is allowed on purpose.
    /// Teacher and Student callers (and any unauthenticated/unknown callers) cannot view them.
    /// </summary>
    public static bool CanViewForceAudit(int? callerRole)
    {
        return callerRole == RoleUtils.Registrar ||
               callerRole == RoleUtils.Admin ||
               callerRole == RoleUtils.ProgramHead ||
               callerRole == RoleUtils.CollegeHead; // College Head is allowed on purpose
    }

    /// <summary>
    /// Masks force enrollment audit fields (IsForced, ForcedByUserID, ForcedReason)
    /// on the given StudyLoadResponseDto according to caller role.
    /// If the caller is not an authorized role (e.g. Teacher, Student, or unauthenticated/unknown),
    /// all three fields are set to null.
    /// </summary>
    public static StudyLoadResponseDto ApplyForceAuditMask(this StudyLoadResponseDto dto, int? callerRole)
    {
        if (!CanViewForceAudit(callerRole))
        {
            dto.IsForced = null;
            dto.ForcedByUserID = null;
            dto.ForcedReason = null;
        }

        return dto;
    }
}
