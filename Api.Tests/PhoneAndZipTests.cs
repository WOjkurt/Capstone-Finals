using System.ComponentModel.DataAnnotations;
using System.Text.Json;
using Api.Common;
using Api.DTOs.Enrollment;
using Xunit;

namespace Api.Tests;

public class PhoneAndZipTests
{
    [Theory]
    [InlineData("09171234567", "09171234567")]
    [InlineData("0917 123 4567", "09171234567")]
    [InlineData("0917-123-4567", "09171234567")]
    [InlineData("+63 917 123 4567", "09171234567")]
    [InlineData("+639171234567", "09171234567")]
    [InlineData("639171234567", "09171234567")]
    [InlineData("9171234567", "09171234567")]
    [InlineData("(032) 253-1234", "0322531234")]
    [InlineData(" abc ", "abc")]
    [InlineData("0917", "0917")]
    public void CleanPhone_WritesNumbersTheSameWay(string input, string expected) =>
        Assert.Equal(expected, PhoneAndZip.CleanPhone(input));

    [Theory]
    [InlineData("09171234567", true)]
    [InlineData("0917123456", false)]
    [InlineData("091712345678", false)]
    [InlineData("08171234567", false)]
    [InlineData("0322531234", false)]
    [InlineData("0917123456a", false)]
    [InlineData("", true)]
    public void MobileNumber_OnlyAccepts11DigitsStartingWith09(string value, bool valid) =>
        Assert.Equal(valid, new MobileNumberAttribute().IsValid(value));

    [Theory]
    [InlineData("09171234567", true)]
    [InlineData("0322531234", true)]
    [InlineData("0281234567", true)]
    [InlineData("N/A", true)]
    [InlineData("2531234", false)]
    [InlineData("hello", false)]
    public void PhoneNumber_AcceptsMobileLandlineOrNA(string value, bool valid) =>
        Assert.Equal(valid, new PhoneNumberAttribute().IsValid(value));

    [Theory]
    [InlineData("6000", true)]
    [InlineData("600", false)]
    [InlineData("60000", false)]
    [InlineData("60a0", false)]
    [InlineData("", true)]
    public void ZipCode_Is4Digits(string value, bool valid) =>
        Assert.Equal(valid, new ZipCodeAttribute().IsValid(value));

    private static readonly JsonSerializerOptions Web = new(JsonSerializerDefaults.Web);

    private static (EnrollmentFormDto Form, List<ValidationResult> Errors) ReadForm(string mobile, string zip)
    {
        var json = $$"""
            {"firstName":"Juan","middleName":"N/A","lastName":"Cruz","suffix":"N/A","dateOfBirth":"2006-03-14",
             "placeOfBirth":"Cebu","sex":"Male","civilStatus":"Single","nationality":"Filipino",
             "mobileNumber":"{{mobile}}","barangay":"Pardo","cityMunicipality":"Cebu City","province":"Cebu",
             "zipCode":"{{zip}}","lastSchoolAttended":"S","schoolAddress":"A","yearGraduated":"2024-03-01",
             "previousCollege":"N/A","previousCourse":"N/A","yearLevel":1}
            """;
        var form = JsonSerializer.Deserialize<EnrollmentFormDto>(json, Web)!;
        var errors = new List<ValidationResult>();
        Validator.TryValidateObject(form, new ValidationContext(form), errors, validateAllProperties: true);
        return (form, errors);
    }

    [Fact]
    public void RegistrarForm_CleansNumbersBeforeChecking()
    {
        var (form, errors) = ReadForm("+63 917-123-4567", " 6000 ");

        Assert.Empty(errors);
        Assert.Equal("09171234567", form.MobileNumber);
        Assert.Equal("6000", form.ZipCode);
    }

    [Fact]
    public void RegistrarForm_RefusesBadMobileAndZip()
    {
        var (_, errors) = ReadForm("0917", "60a0");

        Assert.Contains(errors, e => e.MemberNames.Contains(nameof(EnrollmentFormDto.MobileNumber)));
        Assert.Contains(errors, e => e.MemberNames.Contains(nameof(EnrollmentFormDto.ZipCode)));
    }

    [Theory]
    [InlineData("0917 123 4567", true)]
    [InlineData("(032) 253-1234", true)]
    [InlineData("N/A", true)]
    [InlineData("12345", false)]
    public void RegistrarContact_ChecksNumber(string number, bool valid)
    {
        var contact = JsonSerializer.Deserialize<ContactDto>(
            $$"""{"firstName":"Maria","lastName":"Cruz","relationType":2,"contactNo":"{{number}}"}""", Web)!;
        var errors = new List<ValidationResult>();
        Validator.TryValidateObject(contact, new ValidationContext(contact), errors, validateAllProperties: true);

        Assert.Equal(valid, errors.Count == 0);
    }
}
