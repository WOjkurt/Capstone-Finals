import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/blocs/auth_bloc.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/login_view.dart';
import 'package:sis_registrar_app/views/widgets/password_reset.dart';

class FakeAuthService implements AuthService {
  final sent = <String>[];
  Object? failWith;

  @override
  Future<void> sendPasswordReset(String email) async {
    if (failWith != null) throw failWith!;
    sent.add(email);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeAuthService auth;

  setUp(() async {
    await getIt.reset();
    auth = FakeAuthService();
    getIt.registerSingleton<AuthService>(auth);
  });

  tearDown(() async => getIt.reset());

  Future<void> pumpLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<AuthBloc>(create: (_) => AuthBloc(auth), child: const LoginView()),
    ));
    await tester.pumpAndSettle();
  }

  const forgot = ValueKey('forgot_password_button');
  const confirmation = 'If rita@dbtc-cebu.edu.ph has an account, a password link is on its way. Check your inbox and spam folder.';

  testWidgets('Forgot password needs an email, then sends the link', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(forgot));
    await tester.pumpAndSettle();
    expect(find.textContaining('Type your school email first'), findsOneWidget);
    expect(auth.sent, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, ' rita@dbtc-cebu.edu.ph ');
    await tester.tap(find.byKey(forgot));
    await tester.pumpAndSettle();
    expect(auth.sent, ['rita@dbtc-cebu.edu.ph']);
    expect(find.text(confirmation), findsOneWidget);
  });

  testWidgets('an unknown account gets the same message, so nobody can test who has one', (tester) async {
    auth.failWith = FirebaseAuthException(code: 'user-not-found');
    await pumpLogin(tester);

    await tester.enterText(find.byType(TextFormField).first, 'rita@dbtc-cebu.edu.ph');
    await tester.tap(find.byKey(forgot));
    await tester.pumpAndSettle();

    expect(find.text(confirmation), findsOneWidget);
  });

  testWidgets('a bad address and a network failure say so', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.byType(TextFormField).first, 'rita');

    auth.failWith = FirebaseAuthException(code: 'invalid-email');
    await tester.tap(find.byKey(forgot));
    await tester.pumpAndSettle();
    expect(find.textContaining('does not look right'), findsOneWidget);

    auth.failWith = FirebaseAuthException(code: 'network-request-failed');
    await tester.tap(find.byKey(forgot));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not send the email'), findsOneWidget);
  });

  testWidgets('Change password asks first and sends only on yes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmChangePassword(context, 'rita@dbtc-cebu.edu.ph'),
            child: const Text('open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(auth.sent, isEmpty);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm_change_password')));
    await tester.pumpAndSettle();
    expect(auth.sent, ['rita@dbtc-cebu.edu.ph']);
  });
}
