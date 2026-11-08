import 'package:get_it/get_it.dart';
import 'blocs/clearance_bloc.dart';
import 'blocs/grades_bloc.dart';
import 'blocs/profile_bloc.dart';
import 'blocs/schedule_bloc.dart';
import 'repositories/reenrollment_repository.dart';
import 'repositories/student_repository.dart';
import 'services/auth_service.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Service
  getIt.registerLazySingleton<AuthService>(() => AuthService());

  // Repositories
  getIt.registerLazySingleton<StudentRepository>(
    () => StudentRepository(getIt<AuthService>()),
  );
  getIt.registerLazySingleton<ReenrollmentRepository>(
    () => ReenrollmentRepository(getIt<AuthService>()),
  );

  // Blocs
  getIt.registerFactory<ScheduleBloc>(
    () => ScheduleBloc(getIt<StudentRepository>()),
  );
  getIt.registerFactory<GradesBloc>(
    () => GradesBloc(getIt<StudentRepository>()),
  );
  getIt.registerFactory<ClearanceBloc>(
    () => ClearanceBloc(getIt<StudentRepository>()),
  );
  getIt.registerFactory<ProfileBloc>(
    () => ProfileBloc(getIt<StudentRepository>()),
  );
}

