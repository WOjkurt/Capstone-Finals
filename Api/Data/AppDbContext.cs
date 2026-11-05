using Microsoft.EntityFrameworkCore;
using Api.Domain.Enrollment;
using Api.Domain.IdentityAccess;
using Api.Domain.Grading;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // Enrollment
    public DbSet<AcademicProgram> AcademicPrograms { get; set; }
    public DbSet<AcademicTerm> AcademicTerms { get; set; }
    public DbSet<Subject> Subjects { get; set; }
    public DbSet<SubjectPrerequisite> SubjectPrerequisites { get; set; }
    public DbSet<EnrollmentResponse> EnrollmentResponses { get; set; }
    public DbSet<EnrollmentApplication> EnrollmentApplications { get; set; }
    public DbSet<EnrollmentForm> EnrollmentForms { get; set; }
    public DbSet<Contact> Contacts { get; set; }
    public DbSet<Class> Classes { get; set; }
    public DbSet<ClassSchedule> ClassSchedules { get; set; }
    public DbSet<StudyLoad> StudyLoads { get; set; }
    public DbSet<OverloadApproval> OverloadApprovals { get; set; }
    public DbSet<CreditedSubject> CreditedSubjects { get; set; }
    public DbSet<StudentPersonalDetails> StudentPersonalDetails { get; set; }
    public DbSet<AccreditedSchool> AccreditedSchools { get; set; }
    public DbSet<StudyLoadChange> StudyLoadChanges { get; set; }
    public DbSet<Api.Domain.Audit.ActivityLog> ActivityLogs { get; set; }

    // IdentityAccess
    public DbSet<User> Users { get; set; }
    public DbSet<UserDetails> UserDetails { get; set; }
    public DbSet<Position> Positions { get; set; }

    // Grading
    public DbSet<Grade> Grades { get; set; }
    public DbSet<GradeCorrection> GradeCorrections { get; set; }
    public DbSet<GradeClearance> GradeClearances { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // ── AcademicProgram ──────────────────────────────────────────
        modelBuilder.Entity<AcademicProgram>(entity =>
        {
            entity.Property(p => p.ProgramID)
                .UseIdentityByDefaultColumn();
        });

        // ── AcademicTerm ─────────────────────────────────────────────
        modelBuilder.Entity<AcademicTerm>(entity =>
        {
            entity.Property(t => t.IsActive)
                .HasDefaultValue(false);

            entity.HasIndex(t => t.IsActive)
                .IsUnique()
                .HasFilter("\"IsActive\" = TRUE")
                .HasDatabaseName("idx_academic_terms_single_active");
        });

        // ── User ─────────────────────────────────────────────────────
        modelBuilder.Entity<User>(entity =>
        {
            entity.Property(u => u.IsActive)
                .HasDefaultValue(true);
        });

        // ── UserDetails ─────────────────────────────────────────────
        modelBuilder.Entity<UserDetails>(entity =>
        {
            // One Firebase account ↔ one profile row
            entity.HasIndex(ud => ud.UserID)
                .IsUnique()
                .HasDatabaseName("UQ_UserDetails_UserID");

            entity.HasIndex(ud => ud.LRN)
                .IsUnique()
                .HasFilter("\"LRN\" IS NOT NULL")
                .HasDatabaseName("UQ_UserDetails_LRN");

            entity.HasOne(ud => ud.User)
                .WithOne()
                .HasForeignKey<UserDetails>(ud => ud.UserID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(ud => ud.Program)
                .WithMany()
                .HasForeignKey(ud => ud.ProgramID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(ud => ud.Position)
                .WithMany()
                .HasForeignKey(ud => ud.PositionID)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // ── Subject ──────────────────────────────────────────────────
        modelBuilder.Entity<Subject>(entity =>
        {
            entity.HasOne(s => s.Program)
                .WithMany()
                .HasForeignKey(s => s.ProgramID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(s => new { s.ProgramID, s.SubjectCode })
                .IsUnique()
                .HasDatabaseName("UQ_Subjects_ProgramID_SubjectCode");
        });

        // ── SubjectPrerequisite ──────────────────────────────────────
        modelBuilder.Entity<SubjectPrerequisite>(entity =>
        {
            entity.HasOne(sp => sp.Subject)
                .WithMany()
                .HasForeignKey(sp => sp.SubjectID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(sp => sp.PrerequisiteSubject)
                .WithMany()
                .HasForeignKey(sp => sp.PrerequisiteSubjectID)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // ── EnrollmentResponse ───────────────────────────────────────
        modelBuilder.Entity<EnrollmentResponse>(entity =>
        {
            // Store raw applicant form submission as Postgres jsonb.
            // Npgsql maps JsonDocument ↔ jsonb natively.
            entity.Property(r => r.Data)
                .HasColumnType("jsonb");
        });

        // ── EnrollmentApplication ────────────────────────────────────
        modelBuilder.Entity<EnrollmentApplication>(entity =>
        {
            entity.HasOne(ea => ea.Response)
                .WithMany()
                .HasForeignKey(ea => ea.ResponseID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(ea => ea.Program)
                .WithMany()
                .HasForeignKey(ea => ea.ProgramID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(ea => ea.Term)
                .WithMany()
                .HasForeignKey(ea => ea.TermID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(ea => ea.ReviewedByUser)
                .WithMany()
                .HasForeignKey(ea => ea.ReviewedByUserID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(ea => ea.StudentUser)
                .WithMany()
                .HasForeignKey(ea => ea.StudentUserID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(ea => ea.CreatedByUser)
                .WithMany()
                .HasForeignKey(ea => ea.CreatedByUserID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.Property(ea => ea.CreatedAt)
                .HasDefaultValueSql("NOW()");

            entity.HasIndex(ea => ea.SchoolEmail)
                .IsUnique()
                .HasFilter("\"SchoolEmail\" IS NOT NULL")
                .HasDatabaseName("UQ_EnrollmentApplications_SchoolEmail");
        });

        // ── EnrollmentForm ───────────────────────────────────────────
        modelBuilder.Entity<EnrollmentForm>(entity =>
        {
            entity.HasOne(ef => ef.Application)
                .WithMany()
                .HasForeignKey(ef => ef.ApplicationID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(ef => ef.LRN)
                .HasDatabaseName("IX_EnrollmentForms_LRN");

            // Multi-select checkbox fields stored as jsonb string arrays.
            entity.Property(ef => ef.FamilyMedicalConditionsSelected)
                .HasColumnType("jsonb");
            entity.Property(ef => ef.PastMedicalHistory)
                .HasColumnType("jsonb");
            entity.Property(ef => ef.ImmunizationHistory)
                .HasColumnType("jsonb");
        });

        // ── Contact ─────────────────────────────────────────────────
        modelBuilder.Entity<Contact>(entity =>
        {
            entity.HasOne(c => c.EnrollmentForm)
                .WithMany()
                .HasForeignKey(c => c.EnrollmentID)
                .OnDelete(DeleteBehavior.Cascade);

            // At most one Father (1), Mother (2), and Guardian (3) per enrollment.
            entity.HasIndex(c => new { c.EnrollmentID, c.RelationType })
                .IsUnique()
                .HasDatabaseName("UQ_Contacts_EnrollmentID_RelationType");
        });

        // ── Class ────────────────────────────────────────────────────
        modelBuilder.Entity<Class>(entity =>
        {
            entity.HasOne(c => c.Subject)
                .WithMany()
                .HasForeignKey(c => c.SubjectID)
                .OnDelete(DeleteBehavior.Restrict);

            // Nullable — class can exist before teacher is assigned
            entity.HasOne(c => c.User)
                .WithMany()
                .HasForeignKey(c => c.UserID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(c => c.Term)
                .WithMany()
                .HasForeignKey(c => c.TermID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(c => c.CreatedByUser)
                .WithMany()
                .HasForeignKey(c => c.CreatedByUserID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.Property(c => c.CreatedAt)
                .HasDefaultValueSql("NOW()");
        });

        // ── ClassSchedule ────────────────────────────────────────────
        modelBuilder.Entity<ClassSchedule>(entity =>
        {
            entity.HasOne(cs => cs.Class)
                .WithMany(c => c.ClassSchedules)
                .HasForeignKey(cs => cs.ClassID)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // ── StudyLoad ────────────────────────────────────────────────
        modelBuilder.Entity<StudyLoad>(entity =>
        {
            entity.HasOne(sl => sl.User)
                .WithMany()
                .HasForeignKey(sl => sl.UserID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(sl => sl.Class)
                .WithMany()
                .HasForeignKey(sl => sl.ClassID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(sl => sl.CreatedByUser)
                .WithMany()
                .HasForeignKey(sl => sl.CreatedByUserID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(sl => sl.ForcedByUser)
                .WithMany()
                .HasForeignKey(sl => sl.ForcedByUserID)
                .OnDelete(DeleteBehavior.SetNull);

            entity.Property(sl => sl.CreatedAt)
                .HasDefaultValueSql("NOW()");

            entity.Property(sl => sl.IsForced)
                .HasDefaultValue(false);

            entity.Property(sl => sl.ForcedReason)
                .HasMaxLength(Api.Constants.ValidationConstants.NotesMax);
        });

        // ── Grade ────────────────────────────────────────────────────
        modelBuilder.Entity<Grade>(entity =>
        {
            entity.HasIndex(g => g.StudyLoadID)
                .IsUnique()
                .HasDatabaseName("UQ_Grades_StudyLoadID");

            entity.HasOne(g => g.StudyLoad)
                .WithMany()
                .HasForeignKey(g => g.StudyLoadID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(g => g.SubmittedByUser)
                .WithMany()
                .HasForeignKey(g => g.SubmittedByUserID)
                .OnDelete(DeleteBehavior.Restrict);
        });

        // ── GradeCorrection ─────────────────────────────────────────
        modelBuilder.Entity<GradeCorrection>(entity =>
        {
            entity.HasOne(gc => gc.Grade)
                .WithMany()
                .HasForeignKey(gc => gc.GradeID)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(gc => gc.RequestedByUser)
                .WithMany()
                .HasForeignKey(gc => gc.RequestedByUserID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(gc => gc.ReviewedByUser)
                .WithMany()
                .HasForeignKey(gc => gc.ReviewedByUserID)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // ── GradeClearance ──────────────────────────────────────────
        // Activity log rows keep names as text and have no foreign keys, so deleting people or terms never touches the log.
        modelBuilder.Entity<Api.Domain.Audit.ActivityLog>(entity =>
        {
            entity.HasIndex(l => l.OccurredAt).HasDatabaseName("IX_ActivityLogs_OccurredAt");
            entity.HasIndex(l => l.StudentUserID).HasDatabaseName("IX_ActivityLogs_StudentUserID");
            entity.HasIndex(l => l.Action).HasDatabaseName("IX_ActivityLogs_Action");
        });

        modelBuilder.Entity<CreditedSubject>(entity =>
        {
            entity.HasIndex(c => new { c.UserID, c.SubjectID })
                .IsUnique()
                .HasDatabaseName("UQ_CreditedSubjects_UserID_SubjectID");

            entity.HasOne(c => c.User)
                .WithMany()
                .HasForeignKey(c => c.UserID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(c => c.Subject)
                .WithMany()
                .HasForeignKey(c => c.SubjectID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(c => c.RecordedByUser)
                .WithMany()
                .HasForeignKey(c => c.RecordedByUserID)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<StudyLoadChange>(entity =>
        {
            entity.HasOne(c => c.StudyLoad)
                .WithMany()
                .HasForeignKey(c => c.StudyLoadID)
                .OnDelete(DeleteBehavior.Cascade);
            entity.HasIndex(c => new { c.UserID, c.TermID }).HasDatabaseName("IX_StudyLoadChanges_UserID_TermID");
        });

        modelBuilder.Entity<AccreditedSchool>(entity =>
        {
            entity.HasIndex(s => s.Name).IsUnique().HasDatabaseName("UQ_AccreditedSchools_Name");
        });

        modelBuilder.Entity<StudentPersonalDetails>(entity =>
        {
            entity.HasOne(d => d.User)
                .WithOne()
                .HasForeignKey<StudentPersonalDetails>(d => d.UserID)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(d => d.UpdatedByUser)
                .WithMany()
                .HasForeignKey(d => d.UpdatedByUserID)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<OverloadApproval>(entity =>
        {
            entity.HasIndex(o => new { o.UserID, o.TermID })
                .IsUnique()
                .HasDatabaseName("UQ_OverloadApprovals_UserID_TermID");

            entity.Property(o => o.Units).HasPrecision(5, 1);
            entity.Property(o => o.MaxUnits).HasPrecision(5, 1);

            entity.HasOne(o => o.User)
                .WithMany()
                .HasForeignKey(o => o.UserID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(o => o.Term)
                .WithMany()
                .HasForeignKey(o => o.TermID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(o => o.ApprovedByUser)
                .WithMany()
                .HasForeignKey(o => o.ApprovedByUserID)
                .OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<GradeClearance>(entity =>
        {
            entity.HasIndex(gc => new { gc.UserID, gc.TermID })
                .IsUnique()
                .HasDatabaseName("UQ_GradeClearances_UserID_TermID");

            entity.HasOne(gc => gc.User)
                .WithMany()
                .HasForeignKey(gc => gc.UserID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(gc => gc.Term)
                .WithMany()
                .HasForeignKey(gc => gc.TermID)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(gc => gc.ClearedByUser)
                .WithMany()
                .HasForeignKey(gc => gc.ClearedByUserID)
                .OnDelete(DeleteBehavior.SetNull);
        });
    }
}
