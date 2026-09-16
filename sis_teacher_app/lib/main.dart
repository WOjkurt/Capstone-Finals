import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth_bloc.dart';
import 'blocs/classes_bloc.dart';
import 'blocs/faculty_bloc.dart';
import 'blocs/grade_corrections_bloc.dart';
import 'blocs/grades_bloc.dart';
import 'blocs/program_overview_bloc.dart';
import 'firebase_options.dart';
import 'injection.dart';
import 'services/auth_service.dart';
import 'views/login_view.dart';
import 'views/main_layout_view.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  setupLocator();

  runApp(const SisTeacherApp());
}

class SisTeacherApp extends StatelessWidget {
  const SisTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(getIt<AuthService>()),
        ),
        BlocProvider<ClassesBloc>(
          create: (_) => getIt<ClassesBloc>(),
        ),
        BlocProvider<GradesBloc>(
          create: (_) => getIt<GradesBloc>(),
        ),
        BlocProvider<GradeCorrectionsBloc>(
          create: (_) => getIt<GradeCorrectionsBloc>(),
        ),
        BlocProvider<ProgramOverviewBloc>(
          create: (_) => getIt<ProgramOverviewBloc>(),
        ),
        BlocProvider<FacultyBloc>(
          create: (_) => getIt<FacultyBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'DBTC-Cebu SIS Teacher & Program Head Portal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthenticatedState) {
          return MainLayoutView(auth: state);
        }
        return const LoginView();
      },
    );
  }
}
