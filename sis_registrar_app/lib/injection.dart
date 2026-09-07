import 'package:get_it/get_it.dart';
import 'blocs/applications_bloc.dart';
import 'blocs/clearance_bloc.dart';
import 'blocs/corrections_bloc.dart';
import 'blocs/dashboard_bloc.dart';
import 'blocs/link_accounts_bloc.dart';
import 'blocs/responses_bloc.dart';
import 'blocs/setup_bloc.dart';
import 'repositories/enrollment_repository.dart';
import 'repositories/grading_repository.dart';
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

  // Blocs
  getIt.registerFactory<DashboardBloc>(() => DashboardBloc(
        getIt<EnrollmentRepository>(),
        getIt<GradeCorrectionRepository>(),
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
}
