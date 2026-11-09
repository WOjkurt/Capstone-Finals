import 'package:get_it/get_it.dart';
import 'blocs/applications_bloc.dart';
import 'blocs/clearance_bloc.dart';
import 'blocs/corrections_bloc.dart';
import 'blocs/dashboard_bloc.dart';
import 'blocs/link_accounts_bloc.dart';
import 'blocs/responses_bloc.dart';
import 'blocs/setup_bloc.dart';
import 'blocs/staff_bloc.dart';
import 'repositories/class_repository.dart';
import 'repositories/enrollment_repository.dart';
import 'repositories/grading_repository.dart';
import 'repositories/activity_log_repository.dart';
import 'repositories/report_repository.dart';
import 'repositories/student_record_repository.dart';
import 'repositories/hold_repository.dart';
import 'repositories/curriculum_repository.dart';
import 'repositories/records_import_repository.dart';
import 'repositories/accredited_school_repository.dart';
import 'repositories/school_settings_repository.dart';
import 'repositories/staff_repository.dart';
import 'services/auth_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Service
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Repositories
  getIt.registerLazySingleton<EnrollmentRepository>(
      () => EnrollmentRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<AcademicSetupRepository>(
      () => AcademicSetupRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<GradeClearanceRepository>(
      () => GradeClearanceRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<GradeCorrectionRepository>(
      () => GradeCorrectionRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<UserSearchRepository>(
      () => UserSearchRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<StaffRepository>(
      () => StaffRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<StudentGradeRepository>(
      () => StudentGradeRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<CreditedSubjectRepository>(
      () => CreditedSubjectRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<PromotionRepository>(
      () => PromotionRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<ReportRepository>(
      () => ReportRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<SchoolSettingsRepository>(
      () => SchoolSettingsRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<AccreditedSchoolRepository>(
      () => AccreditedSchoolRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<StudentRecordRepository>(
      () => StudentRecordRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<HoldRepository>(() => HoldRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<CurriculumRepository>(() => CurriculumRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<RecordsImportRepository>(() => RecordsImportRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<ActivityLogRepository>(
      () => ActivityLogRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<ClassRepository>(
      () => ClassRepository(getIt<AuthService>()));

  // Blocs
  getIt.registerFactory<DashboardBloc>(() => DashboardBloc(
        getIt<EnrollmentRepository>(),
        getIt<GradeCorrectionRepository>(),
        getIt<ClassRepository>(),
      ));
  getIt.registerFactory<ResponsesBloc>(() => ResponsesBloc(
        getIt<EnrollmentRepository>(),
        getIt<AcademicSetupRepository>(),
      ));
  getIt.registerFactory<ApplicationsBloc>(() => ApplicationsBloc(
        getIt<EnrollmentRepository>(),
        getIt<AcademicSetupRepository>(),
      ));
  getIt.registerFactory<LinkAccountsBloc>(() => LinkAccountsBloc(
        getIt<EnrollmentRepository>(),
        getIt<AcademicSetupRepository>(),
      ));
  getIt.registerFactory<ClearanceBloc>(() => ClearanceBloc(
        getIt<UserSearchRepository>(),
        getIt<GradeClearanceRepository>(),
      ));
  getIt.registerFactory<SetupBloc>(() => SetupBloc(
        getIt<AcademicSetupRepository>(),
      ));
  getIt.registerFactory<CorrectionsBloc>(() => CorrectionsBloc(
        getIt<GradeCorrectionRepository>(),
      ));
  getIt.registerFactory<StaffBloc>(() => StaffBloc(
        getIt<StaffRepository>(),
      ));
}
