using Api.Auth;
using Api.Repositories;
using Api.Services;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Diagnostics;
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
builder.Services.AddScoped<IStaffService, StaffService>();
builder.Services.AddScoped<IProgramScopingService, ProgramScopingService>();

// ─────────────────────────────────────────────────────────────────────────────
// CORS POLICY — reads allowed origins from configuration.
// Local dev origins are listed in appsettings.Development.json.
// In production (Render), set the Cors__AllowedOrigins__0 env var to your
// deployed frontend URL.
// ─────────────────────────────────────────────────────────────────────────────
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();
builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
        policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod());
});

// Firebase Admin Setup
var firebaseProjectId = builder.Configuration["Firebase:ProjectId"];
var serviceAccountConfigPath = Environment.GetEnvironmentVariable("FIREBASE_KEY_PATH")
    ?? builder.Configuration["Firebase:ServiceAccountKeyPath"]
    ?? "dbtc-firebase-service-account.json";
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
            Credential = CredentialFactory.FromFile<ServiceAccountCredential>(serviceAccountPath).ToGoogleCredential()
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

// Bind to 0.0.0.0 on the port Render assigns (or 5054 for local dev)
var port = Environment.GetEnvironmentVariable("PORT") ?? "5054";
app.Urls.Clear();
app.Urls.Add($"http://0.0.0.0:{port}");

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
    app.MapOpenApi();
    app.MapScalarApiReference();
}
else
{
    app.UseExceptionHandler(errorApp =>
    {
        errorApp.Run(async context =>
        {
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            context.Response.ContentType = "application/json";

            var exceptionFeature = context.Features.Get<IExceptionHandlerPathFeature>();
            if (exceptionFeature?.Error != null)
            {
                var logger = context.RequestServices
                    .GetRequiredService<ILoggerFactory>()
                    .CreateLogger("GlobalExceptionHandler");
                logger.LogError(
                    exceptionFeature.Error,
                    "Unhandled exception occurred processing request to {Path}",
                    exceptionFeature.Path ?? context.Request.Path.Value);
            }

            await context.Response.WriteAsJsonAsync(new { message = "An unexpected error occurred." });
        });
    });
}

app.UseHttpsRedirection();
app.UseRouting();

app.UseCors("Frontend");

app.UseMiddleware<FirebaseAuthMiddleware>();

app.UseAuthorization();
app.MapControllers();

app.Run();
