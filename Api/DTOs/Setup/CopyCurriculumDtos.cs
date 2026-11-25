using System.ComponentModel.DataAnnotations;

namespace Api.DTOs.Setup;

/// <summary>
/// Copying a curriculum into a new one, which is how a 2023-2024 becomes a 2026-2027 without
/// sixty subjects being retyped. The new curriculum belongs to the same programme as the source;
/// only its name and the year it takes effect are chosen.
/// </summary>
public class CopyCurriculumDto
{
    [Required, MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    public int EffectiveFromYear { get; set; }

    /// <summary>
    /// True works out what would happen and saves nothing. A curriculum copy is a large write,
    /// and seeing its shape first is how the Registrar already works with the imports.
    /// </summary>
    public bool DryRun { get; set; }
}

/// <summary>What copying a curriculum would do, or did.</summary>
public class CopyCurriculumResultDto
{
    public bool DryRun { get; set; }

    /// <summary>Null on a dry run: nothing was created to point at.</summary>
    public Guid? CurriculumId { get; set; }

    public string SourceName { get; set; } = string.Empty;
    public string NewName { get; set; } = string.Empty;

    public int SubjectsCopied { get; set; }

    /// <summary>Requisite links re-pointed at the new curriculum's own subjects.</summary>
    public int RequisitesCarried { get; set; }

    /// <summary>
    /// Links that could not be carried, each said in full. A requisite pointing at a subject the
    /// new curriculum does not contain cannot be re-pointed, and dropping one silently would
    /// leave a curriculum that looks complete and is missing a rule.
    /// </summary>
    public List<string> RequisitesDropped { get; set; } = new();
}
