using Api.Auth;
using Api.DTOs.Enrollment;
using Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace Api.Controllers;

/// <summary>
/// Applying to DBTC without an account. This is the only place in the system a stranger can
/// write to, so the whole of that surface is deliberately in one file.
///
/// It replaces the Google Form, which the Registrar maintained by hand. The webhook endpoint the
/// Form posts to cannot be reused: it is signed with a shared secret, and a secret shipped in a
/// web page is not a secret.
///
/// Four things stand between the open internet and the Registrar's queue. The enrollment window,
/// which keeps this shut for most of the year. A per-IP rate limit, tighter than the webhook's.
/// A size limit. And the fact that a submission is only ever an unprocessed response: it creates
/// no account, grants no access, and does nothing at all until the Registrar reviews it.
/// </summary>
[ApiController]
[Route("api/public/enrollment")]
public class PublicEnrollmentController : ControllerBase
{
    private readonly IPublicEnrollmentService _service;

    public PublicEnrollmentController(IPublicEnrollmentService service)
    {
        _service = service;
    }

    private static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);

    /// <summary>
    /// Identifies the request to Postgres as a public applicant before the first query runs.
    ///
    /// Row-level security reads these on every connection open, so this has to happen before the
    /// database is touched, not after. The role is negative because it is not a person: nothing is
    /// ever stored with it, RoleUtils.IsValidRole rejects it, and no sign-in can produce it. It
    /// exists so the policies can name this one path exactly, the way the Forms webhook has -1.
    /// </summary>
    private void AsPublicApplicant() => HttpContext.Items["role"] = RoleUtils.PublicApplicant;

    /// <summary>Whether enrollment is open, and the courses to choose from. No personal data.</summary>
    [HttpGet("status")]
    [AllowAnonymous]
    [EnableRateLimiting("enroll-public")]
    public async Task<IActionResult> GetStatus()
    {
        AsPublicApplicant();
        return Ok(await _service.GetStatusAsync(Today));
    }

    /// <summary>Submits an application. The answer is a reference, because no email is sent.</summary>
    [HttpPost]
    [AllowAnonymous]
    [EnableRateLimiting("enroll-public")]
    [RequestSizeLimit(65_536)]
    public async Task<IActionResult> Submit([FromBody] CreateEnrollmentResponseDto dto)
    {
        AsPublicApplicant();

        if (!ModelState.IsValid)
        {
            return BadRequest(new { message = Api.Common.ValidationMessage.First(ModelState) });
        }

        try
        {
            return Ok(await _service.SubmitAsync(dto, Today));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
