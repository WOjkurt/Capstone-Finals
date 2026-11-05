using Api.Auth;
using Api.DTOs.Credits;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

/// <summary>Schools DBTC accepts credits from (Setup → Accredited schools).</summary>
[ApiController]
[Route("api/accredited-schools")]
public class AccreditedSchoolsController : ControllerBase
{
    private readonly IAccreditedSchoolService _schools;

    public AccreditedSchoolsController(IAccreditedSchoolService schools)
    {
        _schools = schools;
    }

    [HttpGet]
    [RequireRegistrarCollegeHeadOrAdmin]
    public async Task<IActionResult> GetAll() => Ok(await _schools.GetAllAsync());

    [HttpGet("unlisted")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> GetUnlisted() => Ok(await _schools.GetUnlistedAsync());

    [HttpPost]
    [RequireRegistrarOrAdmin]
    public Task<IActionResult> Create([FromBody] SaveAccreditedSchoolDto dto) => Run(() => _schools.CreateAsync(dto));

    [HttpPut("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public Task<IActionResult> Update(Guid id, [FromBody] SaveAccreditedSchoolDto dto) => Run(() => _schools.UpdateAsync(id, dto));

    [HttpDelete("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            await _schools.DeleteAsync(id);
            return NoContent();
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    private async Task<IActionResult> Run<T>(Func<Task<T>> action)
    {
        try
        {
            return Ok(await action());
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
