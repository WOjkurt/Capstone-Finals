using Api.Auth;
using Api.Repositories;
using Api.Services;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;

using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;

// Force .NET network stack to use IPv4 DNS resolution for database connections on macOS
AppContext.SetSwitch("System.Net.DisableIPv6", true);

var builder = WebApplication.CreateBuilder(args);

// DbContext Registration
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Repository Registrations (16 Repositories - matching project Repository Pattern)
builder.Services.AddScoped<IAcademicProgramRepository, AcademicProgramRepository>();
builder.Services.AddScoped<IAcademicTermRepository, AcademicTermRepository>();
builder.Services.AddScoped<ISubjectRepository, SubjectRepository>();
builder.Services.AddScoped<ISubjectPrerequisiteRepository, SubjectPrerequisiteRepository>();
builder.Services.AddScoped<IUserRepository, UserRepository>();
builder.Services.AddScoped<IUserDetailsRepository, UserDetailsRepository>();
builder.Services.AddScoped<IPositionRepository, PositionRepository>();
builder.Services.AddScoped<IEnrollmentResponseRepository, EnrollmentResponseRepository>();
builder.Services.AddScoped<IEnrollmentApplicationRepository, EnrollmentApplicationRepository>();
builder.Services.AddScoped<IEnrollmentFormRepository, EnrollmentFormRepository>();
builder.Services.AddScoped<IContactRepository, ContactRepository>();
builder.Services.AddScoped<IClassRepository, ClassRepository>();
builder.Services.AddScoped<IClassScheduleRepository, ClassScheduleRepository>();
builder.Services.AddScoped<IStudyLoadRepository, StudyLoadRepository>();
builder.Services.AddScoped<IGradeRepository, GradeRepository>();
builder.Services.AddScoped<IGradeCorrectionRepository, GradeCorrectionRepository>();
builder.Services.AddScoped<IGradeClearanceRepository, GradeClearanceRepository>();

// Service Registrations
builder.Services.AddScoped<IEnrollmentService, EnrollmentService>();
builder.Services.AddScoped<IAcademicProgramService, AcademicProgramService>();
builder.Services.AddScoped<IAcademicTermService, AcademicTermService>();
builder.Services.AddScoped<ISubjectService, SubjectService>();
builder.Services.AddScoped<IClassService, ClassService>();
builder.Services.AddScoped<IClassScheduleService, ClassScheduleService>();
builder.Services.AddScoped<IStudyLoadService, StudyLoadService>();
builder.Services.AddScoped<IGradeService, GradeService>();
builder.Services.AddScoped<IGradeCorrectionService, GradeCorrectionService>();
builder.Services.AddScoped<IGradeClearanceService, GradeClearanceService>();

// ─────────────────────────────────────────────────────────────────────────────
// CORS POLICY — LOCAL DEVELOPMENT ONLY
//
// This policy is intentionally permissive for local dev:
//   • Allows any loopback origin (localhost/*) regardless of port, so
//     `flutter run -d chrome` works even when Chrome picks a random ephemeral port.
//   • Allows ALL HTTP methods including PATCH (required by PATCH /api/gradeclearances).
//   • Allows ALL request headers so Authorization: Bearer <token> passes through.
//
// ⚠️  WARNING: Before deploying to any environment beyond local dev, replace this
//     with a strict policy that explicitly lists your production origin(s),
//     restricts methods to only those your API actually exposes, and enumerates
//     only the headers your clients send (Authorization, Content-Type).
// ─────────────────────────────────────────────────────────────────────────────
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFlutterDev", policy =>
    {
        policy
            // Accept any localhost origin regardless of port (handles flutter run's random ports).
            // Uri.IsLoopback covers 127.0.0.1, ::1, and localhost.
            .SetIsOriginAllowed(origin => new Uri(origin).IsLoopback)
            // Allow ALL methods — explicitly includes PATCH (needed for grade clearance toggle)
            // as well as GET, POST, PUT, DELETE, OPTIONS (preflight).
            .AllowAnyMethod()
            // Allow ALL headers — needed for Authorization: Bearer <token> plus any
            // browser-injected headers like Accept, Content-Type, X-Requested-With, etc.
            .AllowAnyHeader();
    });
});

// Firebase Admin Setup
var firebaseProjectId = builder.Configuration["Firebase:ProjectId"];
var serviceAccountConfigPath = builder.Configuration["Firebase:ServiceAccountKeyPath"] ?? "dbtc-firebase-service-account.json";
var serviceAccountPath = Path.IsPathRooted(serviceAccountConfigPath)
    ? serviceAccountConfigPath
    : Path.Combine(Directory.GetCurrentDirectory(), serviceAccountConfigPath);

if (!string.IsNullOrEmpty(firebaseProjectId) && FirebaseApp.DefaultInstance == null)
{
    if (File.Exists(serviceAccountPath))
    {
        FirebaseApp.Create(new AppOptions
        {
            ProjectId = firebaseProjectId,
            Credential = GoogleCredential.FromFile(serviceAccountPath)
        });

        Environment.SetEnvironmentVariable("GOOGLE_APPLICATION_CREDENTIALS", serviceAccountPath);
    }
    else
    {
        Console.WriteLine($"[FIREBASE WARNING] Service account key file not found at: {serviceAccountPath}");
    }
}



builder.Services.AddControllers();
builder.Services.AddOpenApi();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();
app.UseRouting();

app.UseCors("AllowFlutterDev");

app.UseMiddleware<FirebaseAuthMiddleware>();

app.UseAuthorization();
app.MapControllers();

app.Run();
