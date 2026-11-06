using System.Threading.RateLimiting;
using Api.Auth;
using Api.Repositories;
using Api.Services;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Scalar.AspNetCore;
using Microsoft.AspNetCore.Mvc;

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
builder.Services.AddScoped<ICreditedSubjectService, CreditedSubjectService>();
builder.Services.AddScoped<IReportService, ReportService>();
builder.Services.AddScoped<IStudentRecordService, StudentRecordService>();
builder.Services.AddScoped<IAccreditedSchoolService, AccreditedSchoolService>();
builder.Services.AddScoped<IStudyLoadChangeService, StudyLoadChangeService>();
builder.Services.AddScoped<ISchoolSettingsService, SchoolSettingsService>();
builder.Services.AddScoped<IActivityLogService, ActivityLogService>();
builder.Services.AddScoped<IClassService, ClassService>();
builder.Services.AddScoped<IClassScheduleService, ClassScheduleService>();
builder.Services.AddScoped<IStudyLoadService, StudyLoadService>();
builder.Services.AddScoped<IGradeService, GradeService>();
builder.Services.AddScoped<IGradeCorrectionService, GradeCorrectionService>();
builder.Services.AddScoped<IGradeClearanceService, GradeClearanceService>();
builder.Services.AddScoped<IStaffService, StaffService>();
builder.Services.AddScoped<IProgramScopingService, ProgramScopingService>();
builder.Services.AddScoped<ICurriculumImportService, CurriculumImportService>();

// Firebase Auth abstraction — allows tests to inject a mock without touching the real SDK
builder.Services.AddSingleton<IFirebaseAuthVerifier, FirebaseAuthVerifier>();

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
        // Log via the host's built logger so it flows into structured logging (Render log drain etc.)
        var startupLogger = LoggerFactory.Create(b => b.AddConsole()).CreateLogger("Startup");
        startupLogger.LogCritical("[FIREBASE WARNING] Service account key file not found at: {ServiceAccountPath}. Firebase Admin SDK not initialized.", serviceAccountPath);
    }
}



// Rate Limiting Configuration (configurable in appsettings for testing and scaling)
var globalPermitLimit = builder.Configuration.GetValue("RateLimiting:GlobalPermitLimit", 100);
var webhookPermitLimit = builder.Configuration.GetValue("RateLimiting:WebhookPermitLimit", 10);
var searchPermitLimit = builder.Configuration.GetValue("RateLimiting:SearchPermitLimit", 30);

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, cancellationToken) =>
    {
        context.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        context.HttpContext.Response.ContentType = "application/json";

        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            var seconds = (int)Math.Ceiling(retryAfter.TotalSeconds);
            context.HttpContext.Response.Headers.RetryAfter = seconds > 0 ? seconds.ToString() : "60";
        }
        else
        {
            context.HttpContext.Response.Headers.RetryAfter = "60";
        }

        await context.HttpContext.Response.WriteAsJsonAsync(new
        {
            message = "Too many requests. Try again later."
        }, cancellationToken);
    };

    // Global limiter: partition by client IP, 100 requests/minute (configurable)
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(httpContext =>
    {
        var config = httpContext.RequestServices.GetRequiredService<IConfiguration>();
        var limit = config.GetValue("RateLimiting:GlobalPermitLimit", 100);
        var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown_ip";
        return RateLimitPartition.GetFixedWindowLimiter(clientIp, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = limit,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        });
    });

    // Policy "webhook": 60 requests/minute per IP (POST /api/EnrollmentResponses) (configurable)
    options.AddPolicy("webhook", httpContext =>
    {
        var config = httpContext.RequestServices.GetRequiredService<IConfiguration>();
        var limit = config.GetValue("RateLimiting:WebhookPermitLimit", 60);
        var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown_ip";
        return RateLimitPartition.GetFixedWindowLimiter(clientIp, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = limit,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        });
    });

    // Policy "search": 30 requests/minute per IP (configurable).
    // Partitioned by IP only — never reads an unverified token.
    options.AddPolicy("search", httpContext =>
    {
        var config = httpContext.RequestServices.GetRequiredService<IConfiguration>();
        var limit = config.GetValue("RateLimiting:SearchPermitLimit", 30);
        var clientIp = httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown_ip";
        return RateLimitPartition.GetFixedWindowLimiter(clientIp, _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = limit,
            Window = TimeSpan.FromMinutes(1),
            QueueLimit = 0
        });
    });
});

builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(options =>
    {
        options.InvalidModelStateResponseFactory = context =>
        {
            return new BadRequestObjectResult(new { message = Api.Common.ValidationMessage.First(context.ModelState) });
        };
    });
builder.Services.AddOpenApi();
if (!builder.Environment.IsDevelopment())
{
    builder.Services.AddHsts(options =>
    {
        options.MaxAge = TimeSpan.FromDays(180);
        options.IncludeSubDomains = false;
        options.Preload = false;
    });
}

var app = builder.Build();

var webhookSecret = app.Configuration["Webhook:GoogleFormsSecret"];
if (string.IsNullOrEmpty(webhookSecret))
{
    app.Logger.LogCritical("Webhook GoogleFormsSecret is empty or not configured. All webhook requests will be rejected.");
}

// Bind to 0.0.0.0 on the port Render assigns (or 5054 for local dev)
var port = Environment.GetEnvironmentVariable("PORT") ?? "5054";
app.Urls.Clear();
app.Urls.Add($"http://0.0.0.0:{port}");

// 0. Security Headers (must appear on all responses including 401, 403, and 500)
app.UseMiddleware<Api.Middleware.SecurityHeadersMiddleware>();

// 1. Exception Handler
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

// 2. Forwarded Headers (MUST be before HSTS and RateLimiter so the real client IP and HTTPS scheme are used behind Render's reverse proxy)
var forwardedHeadersOptions = new ForwardedHeadersOptions
{
    ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto
};
forwardedHeadersOptions.KnownIPNetworks.Clear();
forwardedHeadersOptions.KnownProxies.Clear();
app.UseForwardedHeaders(forwardedHeadersOptions);

// 3. HSTS (must come AFTER UseForwardedHeaders so X-Forwarded-Proto: https is recognized behind Render's proxy)
if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

// 4. HTTPS Redirection
app.UseHttpsRedirection();

// 4. Routing
app.UseRouting();

// 5. CORS (before rate limiter so preflight OPTIONS passes without consuming quota)
app.UseCors("Frontend");

// 6. Rate Limiter
app.UseRateLimiter();

// 7. Auth Middleware
app.UseMiddleware<FirebaseAuthMiddleware>();

// 8. Authorization
app.UseAuthorization();

// 9. Controllers
app.MapControllers();

app.Run();

public partial class Program { }
