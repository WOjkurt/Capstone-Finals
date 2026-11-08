using System.ComponentModel.DataAnnotations;
using Api.Auth;
using Api.Common;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.DTOs.Setup;
using Xunit;

namespace Api.Tests;

public class EnrollmentPeriodTests
{
    private static AcademicTerm Term(string? opens, string? closes) => new()
    {
        SchoolYear = "2026-2027",
        Semester = 2,
        EnrollmentOpensOn = opens == null ? null : DateOnly.Parse(opens),
        EnrollmentClosesOn = closes == null ? null : DateOnly.Parse(closes),
    };

    [Theory]
    [InlineData("2026-11-16", false)]
    [InlineData("2026-11-17", true)]
    [InlineData("2026-11-22", true)]
    [InlineData("2026-11-28", true)]
    [InlineData("2026-11-29", false)]
    public void Open_FromStartDateUntilEndDate(string today, bool open) =>
        Assert.Equal(open, Term("2026-11-17", "2026-11-28").IsEnrollmentOpen(DateOnly.Parse(today)));

    [Fact]
    public void NoDates_IsClosed() =>
        Assert.False(Term(null, null).IsEnrollmentOpen(DateOnly.Parse("2026-11-20")));

    [Fact]
    public void SchoolClock_UsesPhilippineDate()
    {
        // 4:30 PM UTC on Nov 16 is already 12:30 AM on Nov 17 in Cebu.
        Assert.Equal(new DateOnly(2026, 11, 17), SchoolClock.Today(new DateTime(2026, 11, 16, 16, 30, 0, DateTimeKind.Utc)));
        Assert.Equal(new DateOnly(2026, 11, 16), SchoolClock.Today(new DateTime(2026, 11, 16, 15, 59, 0, DateTimeKind.Utc)));
    }

    private static List<ValidationResult> Validate(string? opens, string? closes)
    {
        var dto = new SetEnrollmentPeriodDto
        {
            OpensOn = opens == null ? null : DateOnly.Parse(opens),
            ClosesOn = closes == null ? null : DateOnly.Parse(closes),
        };
        var results = new List<ValidationResult>();
        Validator.TryValidateObject(dto, new ValidationContext(dto), results, validateAllProperties: true);
        return results;
    }

    [Theory]
    [InlineData("2026-11-17", "2026-11-28", true)]
    [InlineData("2026-11-17", "2026-11-17", true)]
    [InlineData(null, null, true)]
    [InlineData("2026-11-28", "2026-11-17", false)]
    [InlineData("2026-11-17", null, false)]
    [InlineData(null, "2026-11-28", false)]
    public void Dates_MustBeBothOrNeither_AndInOrder(string? opens, string? closes, bool valid) =>
        Assert.Equal(valid, Validate(opens, closes).Count == 0);

    [Fact]
    public void OnlyRegistrarOrAdmin_CanSetDates()
    {
        var method = typeof(AcademicTermsController).GetMethod(nameof(AcademicTermsController.SetEnrollmentPeriod))!;
        Assert.NotEmpty(method.GetCustomAttributes(typeof(RequireRegistrarOrAdminAttribute), false));
    }
}
