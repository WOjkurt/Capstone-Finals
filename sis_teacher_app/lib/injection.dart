import 'package:get_it/get_it.dart';
import 'blocs/classes_bloc.dart';
import 'blocs/grade_corrections_bloc.dart';
import 'blocs/grades_bloc.dart';
import 'repositories/class_repository.dart';
import 'repositories/grades_repository.dart';
import 'repositories/grading_repository.dart';
import 'services/auth_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Service
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Repositories
  getIt.registerLazySingleton<ClassRepository>(
      () => ClassRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<GradesRepository>(
      () => GradesRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<GradeCorrectionRepository>(
      () => GradeCorrectionRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<UserSearchRepository>(
      () => UserSearchRepository(getIt<AuthService>()));

  // Blocs
  getIt.registerFactory<ClassesBloc>(
      () => ClassesBloc(getIt<ClassRepository>()));
  getIt.registerFactory<GradesBloc>(
      () => GradesBloc(getIt<ClassRepository>(), getIt<GradesRepository>()));
  getIt.registerFactory<GradeCorrectionsBloc>(
      () => GradeCorrectionsBloc(getIt<GradeCorrectionRepository>()));
}
