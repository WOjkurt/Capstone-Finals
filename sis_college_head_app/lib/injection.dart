import 'package:get_it/get_it.dart';
import 'blocs/faculty_bloc.dart';
import 'blocs/irregular_bloc.dart';
import 'blocs/pending_loads_bloc.dart';
import 'blocs/students_bloc.dart';
import 'repositories/class_repository.dart';
import 'repositories/setup_repository.dart';
import 'repositories/student_repository.dart';
import 'repositories/teacher_repository.dart';
import 'services/auth_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Service
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Repositories
  getIt.registerLazySingleton<AcademicSetupRepository>(
      () => AcademicSetupRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<StudentRepository>(
      () => StudentRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<ClassRepository>(
      () => ClassRepository(getIt<AuthService>()));
  getIt.registerLazySingleton<TeacherRepository>(
      () => TeacherRepository(getIt<AuthService>()));

  // Blocs
  getIt.registerFactory<StudentsBloc>(() => StudentsBloc(
        getIt<StudentRepository>(),
        getIt<AcademicSetupRepository>(),
      ));
  getIt.registerFactory<FacultyBloc>(() => FacultyBloc(
        getIt<TeacherRepository>(),
        getIt<ClassRepository>(),
        getIt<AcademicSetupRepository>(),
      ));
  getIt.registerFactory<IrregularBloc>(
      () => IrregularBloc(getIt<StudentRepository>()));
  getIt.registerFactory<PendingLoadsBloc>(() => PendingLoadsBloc(
        getIt<ClassRepository>(),
        getIt<AcademicSetupRepository>(),
      ));
}
