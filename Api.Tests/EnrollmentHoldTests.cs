using System.ComponentModel.DataAnnotations;
using Api.Auth;
using Api.Controllers;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.DTOs.Holds;
using Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace Api.Tests;

public class EnrollmentHoldTests : IDisposable
{
    private readonly AppDbContext _context;
    private readonly EnrollmentHoldService _service;
    private readonly Guid _registrar = Guid.NewGuid();
    private readonly Guid _student = Guid.NewGuid();
    private readonly Guid _teacher = Guid.NewGuid();

    public EnrollmentHoldTests()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        _context = new TestAppDbContext(options);
        _service = new EnrollmentHoldService(_context);

        _context.Users.AddRange(
            new User { UserID = _registrar, FirebaseUID = "fb-r", Email = "r@x.com", Role = RoleUtils.Registrar, IsActive = true },
            new User { UserID = _student, FirebaseUID = "fb-s", Email = "s@x.com", Role = RoleUtils.Student, IsActive = true },
            new User { UserID = _teacher, FirebaseUID = "fb-t", Email = "t@x.com", Role = RoleUtils.Teacher, IsActive = true });
        _context.UserDetails.Add(new UserDetails { UserDetailID = Guid.NewGuid(), UserID = _registrar, Firstname = "Rita", Lastname = "Reg" });
        _context.SaveChanges();
    }

    public void Dispose()
    {
        _context.Database.EnsureDeleted();
        _context.Dispose();
    }

    private static AddEnrollmentHoldDto Unpaid(string? note = "Balance P2,500") =>
        new() { Reason = EnrollmentHoldReasons.UnpaidBalance, Note = note };

    [Fact]
    public async Task Add_ThenRemove_KeepsHistoryWithNames()
    {
        var added = await _service.AddAsync(_student, Unpaid(), _registrar, RoleUtils.Registrar);
        Assert.True(added.IsOpen);
        Assert.Equal("Unpaid balance", added.ReasonLabel);
        Assert.Equal("Rita Reg", added.AddedByName);

        var removed = await _service.RemoveAsync(added.HoldId, new RemoveEnrollmentHoldDto { Note = " Paid, OR #12345 " }, _registrar, RoleUtils.Registrar);
        Assert.False(removed.IsOpen);
        Assert.Equal("Paid, OR #12345", removed.RemovalNote);
        Assert.Equal("Rita Reg", removed.RemovedByName);

        var all = await _service.GetByStudentAsync(_student);
        Assert.Single(all);
        Assert.False(all[0].IsOpen);
    }

    [Fact]
    public async Task OpenHoldsComeFirst()
    {
        var old = await _service.AddAsync(_student, Unpaid(), _registrar, RoleUtils.Registrar);
        await _service.RemoveAsync(old.HoldId, new RemoveEnrollmentHoldDto(), _registrar, RoleUtils.Registrar);
        await _service.AddAsync(_student, new AddEnrollmentHoldDto { Reason = EnrollmentHoldReasons.Other, Note = "Missing Form 137" }, _registrar, RoleUtils.Registrar);

        var all = await _service.GetByStudentAsync(_student);
        Assert.True(all[0].IsOpen);
        Assert.Equal("Missing Form 137", all[0].Note);
    }

    [Fact]
    public async Task SameOpenReasonTwice_IsRefused_ButAgainAfterRemovalIsAllowed()
    {
        var first = await _service.AddAsync(_student, Unpaid(), _registrar, RoleUtils.Registrar);
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.AddAsync(_student, Unpaid(), _registrar, RoleUtils.Registrar));

        await _service.RemoveAsync(first.HoldId, new RemoveEnrollmentHoldDto(), _registrar, RoleUtils.Registrar);
        var again = await _service.AddAsync(_student, Unpaid(), _registrar, RoleUtils.Registrar);
        Assert.True(again.IsOpen);
    }

    [Fact]
    public async Task OnlyStudentsCanGetHolds()
    {
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.AddAsync(_teacher, Unpaid(), _registrar, RoleUtils.Registrar));
        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.AddAsync(Guid.NewGuid(), Unpaid(), _registrar, RoleUtils.Registrar));
    }

    [Fact]
    public async Task RemovingTwice_IsRefused()
    {
        var hold = await _service.AddAsync(_student, Unpaid(), _registrar, RoleUtils.Registrar);
        await _service.RemoveAsync(hold.HoldId, new RemoveEnrollmentHoldDto(), _registrar, RoleUtils.Registrar);
        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.RemoveAsync(hold.HoldId, new RemoveEnrollmentHoldDto(), _registrar, RoleUtils.Registrar));
    }

    [Theory]
    [InlineData("UnpaidBalance", null, true)]
    [InlineData("Other", "Missing Form 137", true)]
    [InlineData("Other", " ", false)]
    [InlineData("Library", "Book not returned", false)]
    public void Reason_MustBeKnown_AndOtherNeedsANote(string reason, string? note, bool valid)
    {
        var dto = new AddEnrollmentHoldDto { Reason = reason, Note = note };
        var errors = new List<ValidationResult>();
        Validator.TryValidateObject(dto, new ValidationContext(dto), errors, validateAllProperties: true);
        Assert.Equal(valid, errors.Count == 0);
    }

    [Fact]
    public async Task Controller_ReturnsNotFoundAndConflict()
    {
        var controller = new EnrollmentHoldsController(_service)
        {
            ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() },
        };
        controller.HttpContext.Items["user_id"] = _registrar;

        Assert.IsType<OkObjectResult>(await controller.Add(_student, Unpaid()));
        Assert.IsType<ConflictObjectResult>(await controller.Add(_student, Unpaid()));
        Assert.IsType<NotFoundObjectResult>(await controller.Add(_teacher, Unpaid()));
        Assert.IsType<NotFoundObjectResult>(await controller.Remove(Guid.NewGuid(), new RemoveEnrollmentHoldDto()));
    }

    [Theory]
    [InlineData(nameof(EnrollmentHoldsController.Add), typeof(RequireAccountingOrRegistrarAttribute))]
    [InlineData(nameof(EnrollmentHoldsController.Remove), typeof(RequireAccountingOrRegistrarAttribute))]
    [InlineData(nameof(EnrollmentHoldsController.GetByStudent), typeof(RoleAuthorizationAttribute))]
    public void Endpoints_AreLimitedToStaff(string method, Type attribute) =>
        Assert.NotEmpty(typeof(EnrollmentHoldsController).GetMethod(method)!.GetCustomAttributes(attribute, false));

    // ── Accounting is confined to the one reason its office is responsible for ──────

    [Fact]
    public async Task Accounting_CanRaiseAndLift_AnUnpaidBalanceHold()
    {
        var added = await _service.AddAsync(_student, Unpaid(), _registrar, RoleUtils.Accounting);
        Assert.Equal(EnrollmentHoldReasons.UnpaidBalance, added.Reason);

        var removed = await _service.RemoveAsync(added.HoldId, new RemoveEnrollmentHoldDto { Note = "Settled" },
            _registrar, RoleUtils.Accounting);
        Assert.False(removed.IsOpen);
    }

    [Fact]
    public async Task Accounting_CannotRaise_AnOtherHold()
    {
        var other = new AddEnrollmentHoldDto { Reason = EnrollmentHoldReasons.Other, Note = "Missing Form 137" };
        await Assert.ThrowsAsync<UnauthorizedAccessException>(
            () => _service.AddAsync(_student, other, _registrar, RoleUtils.Accounting));
    }

    /// <summary>
    /// The side that matters. Raising the wrong hold is a nuisance; lifting a Registrar's hold
    /// would let a student straight past a block the Registrar put there deliberately.
    /// </summary>
    [Fact]
    public async Task Accounting_CannotLift_AHoldTheRegistrarRaised()
    {
        var other = new AddEnrollmentHoldDto { Reason = EnrollmentHoldReasons.Other, Note = "Missing Form 137" };
        var raised = await _service.AddAsync(_student, other, _registrar, RoleUtils.Registrar);

        await Assert.ThrowsAsync<UnauthorizedAccessException>(
            () => _service.RemoveAsync(raised.HoldId, new RemoveEnrollmentHoldDto(), _registrar, RoleUtils.Accounting));
    }
}
