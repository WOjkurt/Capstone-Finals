using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Api.Common;

public static class ValidationMessage
{
    /// <summary>
    /// The error to show the user. When a request body cannot be read, ASP.NET also reports "The dto field is
    /// required", which says nothing useful, so a specific error is preferred over the body parameter's own.
    /// </summary>
    public static string First(ModelStateDictionary modelState)
    {
        var errors = modelState
            .Where(e => e.Value != null && e.Value.Errors.Count > 0)
            .SelectMany(e => e.Value!.Errors.Select(err => (e.Key, Text: err.ErrorMessage.Length > 0 ? err.ErrorMessage : err.Exception?.Message ?? "")))
            .Where(e => e.Text.Length > 0)
            .ToList();
        var specific = errors.Where(e => !e.Text.EndsWith("field is required.", StringComparison.Ordinal) || e.Key.Contains('.')).ToList();
        return (specific.Count > 0 ? specific : errors).Select(e => e.Text).FirstOrDefault() ?? "Invalid request.";
    }
}
