import 'package:get_it/get_it.dart';
import 'blocs/grades_bloc.dart';
import 'blocs/schedule_bloc.dart';
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

  // Blocs
  getIt.registerFactory<ScheduleBloc>(
    () => ScheduleBloc(getIt<StudentRepository>()),
  );
  getIt.registerFactory<GradesBloc>(
    () => GradesBloc(getIt<StudentRepository>()),
  );
}
