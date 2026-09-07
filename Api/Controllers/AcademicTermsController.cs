using Api.Auth;
using Api.DTOs.Setup;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AcademicTermsController : ControllerBase
{
    private readonly IAcademicTermService _termService;

    public AcademicTermsController(IAcademicTermService termService)
    {
        _termService = termService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var terms = await _termService.GetAllAsync();
        return Ok(terms);
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById(Guid id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var term = await _termService.GetByIdAsync(id);
        if (term == null)
        {
            return NotFound(new { message = $"AcademicTerm with ID '{id}' was not found." });
        }

        return Ok(term);
    }

    [HttpPost]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Create([FromBody] CreateAcademicTermDto dto)
    {
        var term = await _termService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = term.TermID }, term);
    }

    [HttpPut("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Update(Guid id, [FromBody] CreateAcademicTermDto dto)
    {
        try
        {
            var term = await _termService.UpdateAsync(id, dto);
            return Ok(term);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpDelete("{id:guid}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Delete(Guid id)
    {
        try
        {
            await _termService.DeleteAsync(id);
            return Ok(new { message = "AcademicTerm deleted successfully." });
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
