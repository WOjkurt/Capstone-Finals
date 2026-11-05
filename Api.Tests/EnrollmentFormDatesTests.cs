using System.Text.Json;
using Api.DTOs.Enrollment;
using Xunit;

namespace Api.Tests;

// The Registrar app sends these dates as typed or as they came from the Google Form.
public class EnrollmentFormDatesTests
{
    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    private static string Payload(string dob, string yearGraduated, string? contactDob = null) => $$"""
    {"responseID":"7f6f3a4e-3e1b-4a44-9a51-111111111111","programID":1,"termID":"7f6f3a4e-3e1b-4a44-9a51-222222222222",
     "form":{"firstName":"Ana","middleName":"","lastName":"Cruz","suffix":"","dateOfBirth":"{{dob}}","placeOfBirth":"Cebu","sex":"Female",
       "civilStatus":"Single","nationality":"Filipino","mobileNumber":"0912","barangay":"b","cityMunicipality":"c","province":"p","zipCode":"6000",
       "lastSchoolAttended":"s","schoolAddress":"a","yearGraduated":"{{yearGraduated}}","previousCollege":"","previousCourse":"","yearLevel":1},
     "contacts":[{"firstName":"Mama","lastName":"Cruz","relationType":2,"occupation":"","contactNo":"0912"{{(contactDob == null ? "" : $",\"dateOfBirth\":\"{contactDob}\"")}}}]}
    """;

    [Theory]
    [InlineData("2007-05-01", "2024-05-30", 2007, 5, 1, 2024, 5, 30)]
    [InlineData("5/1/2007", "2024", 2007, 5, 1, 2024, 1, 1)]
    [InlineData("05/01/2007", "3/30/2024", 2007, 5, 1, 2024, 3, 30)]
    [InlineData("May 1, 2007", "2024-05", 2007, 5, 1, 2024, 5, 1)]
    public void FormDates_AcceptTheWaysPeopleWriteThem(string dob, string grad, int y, int m, int d, int gy, int gm, int gd)
    {
        var dto = JsonSerializer.Deserialize<CreateEnrollmentApplicationDto>(Payload(dob, grad), Web)!;

        Assert.Equal(new DateOnly(y, m, d), dto.Form.DateOfBirth);
        Assert.Equal(new DateOnly(gy, gm, gd), dto.Form.YearGraduated);
    }

    [Fact]
    public void EmptyDates_AreLeftEmpty()
    {
        var dto = JsonSerializer.Deserialize<CreateEnrollmentApplicationDto>(Payload("2007-05-01", "", ""), Web)!;

        Assert.Equal(default, dto.Form.YearGraduated);
        Assert.Null(dto.Contacts.Single().DateOfBirth);
    }

    [Fact]
    public void TheErrorShown_NamesTheProblem_NotTheDtoField()
    {
        var state = new Microsoft.AspNetCore.Mvc.ModelBinding.ModelStateDictionary();
        state.AddModelError("dto", "The dto field is required.");
        state.AddModelError("$.form.yearGraduated", "\"last year\" is not a date we can read.");
        Assert.Equal("\"last year\" is not a date we can read.", Api.Common.ValidationMessage.First(state));

        var plain = new Microsoft.AspNetCore.Mvc.ModelBinding.ModelStateDictionary();
        plain.AddModelError("Name", "The Name field is required.");
        Assert.Equal("The Name field is required.", Api.Common.ValidationMessage.First(plain));
        Assert.Equal("Invalid request.", Api.Common.ValidationMessage.First(new Microsoft.AspNetCore.Mvc.ModelBinding.ModelStateDictionary()));
    }

    [Fact]
    public void ADateThatCannotBeRead_SaysWhatToType()
    {
        var ex = Assert.Throws<JsonException>(() => JsonSerializer.Deserialize<CreateEnrollmentApplicationDto>(Payload("2007-05-01", "last year"), Web));

        Assert.Contains("last year", ex.Message);
        Assert.Contains("yearGraduated", ex.Path);
    }
}
