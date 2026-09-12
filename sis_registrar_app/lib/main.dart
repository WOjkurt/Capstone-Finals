import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'blocs/applications_bloc.dart';
import 'blocs/auth_bloc.dart';
import 'blocs/clearance_bloc.dart';
import 'blocs/corrections_bloc.dart';
import 'blocs/dashboard_bloc.dart';
import 'blocs/link_accounts_bloc.dart';
import 'blocs/responses_bloc.dart';
import 'blocs/setup_bloc.dart';
import 'blocs/staff_bloc.dart';
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

  runApp(const SisRegistrarApp());
}

class SisRegistrarApp extends StatelessWidget {
  const SisRegistrarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(getIt<AuthService>()),
        ),
        BlocProvider<DashboardBloc>(
          create: (_) => getIt<DashboardBloc>(),
        ),
        BlocProvider<ResponsesBloc>(
          create: (_) => getIt<ResponsesBloc>(),
        ),
        BlocProvider<ApplicationsBloc>(
          create: (_) => getIt<ApplicationsBloc>(),
        ),
        BlocProvider<LinkAccountsBloc>(
          create: (_) => getIt<LinkAccountsBloc>(),
        ),
        BlocProvider<ClearanceBloc>(
          create: (_) => getIt<ClearanceBloc>(),
        ),
        BlocProvider<SetupBloc>(
          create: (_) => getIt<SetupBloc>(),
        ),
        BlocProvider<CorrectionsBloc>(
          create: (_) => getIt<CorrectionsBloc>(),
        ),
        BlocProvider<StaffBloc>(
          create: (_) => getIt<StaffBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'DBTC-Cebu SIS Registrar Portal',
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
