import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/auth_bloc.dart';
import 'blocs/classes_bloc.dart';
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
