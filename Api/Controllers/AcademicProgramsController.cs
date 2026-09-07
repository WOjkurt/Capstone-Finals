using Api.Auth;
using Api.DTOs.Setup;
using Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AcademicProgramsController : ControllerBase
{
    private readonly IAcademicProgramService _programService;

    public AcademicProgramsController(IAcademicProgramService programService)
    {
        _programService = programService;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var programs = await _programService.GetAllAsync();
        return Ok(programs);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        if (!HttpContext.Items.TryGetValue("user_id", out var userIdObj) || userIdObj is not Guid || (Guid)userIdObj == Guid.Empty)
        {
            return Unauthorized(new { message = "Authentication required." });
        }

        var program = await _programService.GetByIdAsync(id);
        if (program == null)
        {
            return NotFound(new { message = $"AcademicProgram with ID '{id}' was not found." });
        }

        return Ok(program);
    }

    [HttpPost]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Create([FromBody] CreateAcademicProgramDto dto)
    {
        var program = await _programService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = program.ProgramID }, program);
    }

    [HttpPut("{id:int}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Update(int id, [FromBody] CreateAcademicProgramDto dto)
    {
        try
        {
            var program = await _programService.UpdateAsync(id, dto);
            return Ok(program);
        }
        catch (KeyNotFoundException ex)
        {
            return NotFound(new { message = ex.Message });
        }
    }

    [HttpDelete("{id:int}")]
    [RequireRegistrarOrAdmin]
    public async Task<IActionResult> Delete(int id)
    {
        try
        {
            await _programService.DeleteAsync(id);
            return Ok(new { message = "AcademicProgram deleted successfully." });
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
