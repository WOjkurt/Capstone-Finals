using Api.Common;
using Xunit;

namespace Api.Tests;

// 1.0-5.0 in 0.1 steps plus quarter steps; above 3.0 is Failed.
public class GradeScaleTests
{
    [Theory]
    [InlineData("1.0")]
    [InlineData("1.1")]
    [InlineData("1.25")]
    [InlineData("2.75")]
    [InlineData("3.0")]
    [InlineData("3.1")]
    [InlineData("4.0")]
    [InlineData("4.9")]
    [InlineData("5.0")]
    public void ValidGrades(string value) => Assert.True(GradeScale.IsValid(decimal.Parse(value)));

    [Theory]
    [InlineData("0.9")]
    [InlineData("5.1")]
    [InlineData("3.15")]
    [InlineData("88")]
    [InlineData("0")]
    public void InvalidGrades(string value) => Assert.False(GradeScale.IsValid(decimal.Parse(value)));

    [Theory]
    [InlineData("3.0", 1)]
    [InlineData("3.1", 2)]
    [InlineData("1.0", 1)]
    [InlineData("5.0", 2)]
    public void RemarksFollowThePassingLine(string value, int remarks) =>
        Assert.Equal(remarks, GradeScale.Remarks(decimal.Parse(value)));

    [Fact]
    public void EnsureValid_AllowsNull_AndRejectsOffScale()
    {
        GradeScale.EnsureValid(null);
        var ex = Assert.Throws<InvalidOperationException>(() => GradeScale.EnsureValid(3.15m));
        Assert.Contains("1.0 to 5.0", ex.Message);
    }
}
