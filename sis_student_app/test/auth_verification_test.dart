import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_student_app/blocs/auth_bloc.dart';
import 'package:sis_student_app/services/auth_service.dart';
import 'package:sis_student_app/utils/error_handler.dart';
import 'package:sis_student_app/views/verify_email_view.dart';

class FakeUser implements User {
  final String _email;
  final bool _emailVerified;
  FakeUser({required String email, bool emailVerified = false})
      : _email = email,
        _emailVerified = emailVerified;

  @override
  String? get email => _email;

  @override
  bool get emailVerified => _emailVerified;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  final String _email;
  FakeUserCredential({required String email}) : _email = email;

  @override
  User? get user => FakeUser(email: _email);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  @override
  Future<void> sendPasswordReset(String email) async {}

  bool isVerified = false;
  bool shouldThrowEmailNotVerifiedOnLogin = false;
  bool shouldThrow403OnApi = false;
  bool sendVerificationCalled = false;
  bool reloadCalled = false;
  bool signOutCalled = false;
  User? fakeUser;
  Map<String, dynamic>? mockUserInfo;

  @override
  User? get currentUser => fakeUser;

  @override
  Stream<User?> get userStream => const Stream.empty();

  @override
  Future<String?> getToken() async => 'fake-token';

  @override
  Future<UserCredential> signUp(String email, String password) async {
    return FakeUserCredential(email: email);
  }

  @override
  Future<void> sendEmailVerification() async {
    sendVerificationCalled = true;
  }

  @override
  Future<bool> reloadUserAndCheckVerified() async {
    reloadCalled = true;
    return isVerified;
  }

  @override
  Future<Map<String, dynamic>?> signInAndVerify(
      String email, String password) async {
    if (shouldThrowEmailNotVerifiedOnLogin) {
      throw EmailNotVerifiedException(email);
    }
    if (shouldThrow403OnApi) {
      throw ApiException(
        statusCode: 403,
        message:
            'Failed to fetch user info: {"error":"email_not_verified","message":"Please verify your email address, then sign in again."}',
      );
    }
    return mockUserInfo;
  }

  @override
  Future<Map<String, dynamic>?> fetchCurrentUserInfo() async {
    if (shouldThrow403OnApi) {
      throw ApiException(
        statusCode: 403,
        message:
            'Failed to fetch user info: {"error":"email_not_verified","message":"Please verify your email address, then sign in again."}',
      );
    }
    return mockUserInfo;
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<Map<String, String>> getAuthHeaders() async =>
      {'Authorization': 'Bearer fake-token', 'Content-Type': 'application/json'};
}

void main() {
  group('AuthBloc - Email Verification Flow', () {
    late FakeAuthService authService;
    late AuthBloc authBloc;

    setUp(() {
      authService = FakeAuthService();
      authBloc = AuthBloc(authService);
    });

    tearDown(() {
      authBloc.close();
    });

    test('SignUpRequested transitions to EmailVerificationRequiredState', () async {
      final states = <AuthState>[];
      authBloc.stream.listen(states.add);

      authBloc.add(SignUpRequested('newstudent@dbtc-cebu.edu.ph', 'Password123!'));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthState>((state) {
            return state is EmailVerificationRequiredState &&
                state.email == 'newstudent@dbtc-cebu.edu.ph';
          }),
        ]),
      );
    });

    test('LoginRequested with unverified email emits EmailVerificationRequiredState with no API call', () async {
      authService.shouldThrowEmailNotVerifiedOnLogin = true;

      authBloc.add(LoginRequested('unverified@dbtc-cebu.edu.ph', 'Password123!'));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthState>((state) {
            return state is EmailVerificationRequiredState &&
                state.email == 'unverified@dbtc-cebu.edu.ph';
          }),
        ]),
      );
    });

    test('LoginRequested receiving 403 email_not_verified emits EmailVerificationRequiredState', () async {
      authService.shouldThrow403OnApi = true;

      authBloc.add(LoginRequested('test403@dbtc-cebu.edu.ph', 'Password123!'));

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthState>((state) {
            return state is EmailVerificationRequiredState &&
                state.email == 'test403@dbtc-cebu.edu.ph';
          }),
        ]),
      );
    });

    test('CheckEmailVerifiedRequested when still unverified remains in EmailVerificationRequiredState', () async {
      authService.fakeUser = FakeUser(email: 'checking@dbtc-cebu.edu.ph');
      authService.isVerified = false;

      authBloc.add(CheckEmailVerifiedRequested());

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthState>((state) {
            return state is EmailVerificationRequiredState &&
                state.email == 'checking@dbtc-cebu.edu.ph' &&
                (state.message?.contains('Email not verified yet') ?? false);
          }),
        ]),
      );
      expect(authService.reloadCalled, isTrue);
    });

    test('CheckEmailVerifiedRequested when verified transitions to AuthenticatedState', () async {
      authService.fakeUser = FakeUser(email: 'verified@dbtc-cebu.edu.ph');
      authService.isVerified = true;
      authService.mockUserInfo = {
        'role': 5,
        'roleName': 'Student',
        'userId': 'student-uuid-1234',
        'email': 'verified@dbtc-cebu.edu.ph',
      };

      authBloc.add(CheckEmailVerifiedRequested());

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          isA<AuthLoading>(),
          predicate<AuthState>((state) {
            return state is AuthenticatedState &&
                state.email == 'verified@dbtc-cebu.edu.ph' &&
                state.role == 5 &&
                state.userId == 'student-uuid-1234';
          }),
        ]),
      );
      expect(authService.reloadCalled, isTrue);
    });

    test('SendVerificationEmailRequested triggers sendEmailVerification on service', () async {
      authService.fakeUser = FakeUser(email: 'resend@dbtc-cebu.edu.ph');

      authBloc.add(SendVerificationEmailRequested());

      await expectLater(
        authBloc.stream,
        emitsInOrder([
          predicate<AuthState>((state) {
            return state is EmailVerificationRequiredState &&
                state.email == 'resend@dbtc-cebu.edu.ph' &&
                (state.message?.contains('verification email has been sent') ?? false);
          }),
        ]),
      );
      expect(authService.sendVerificationCalled, isTrue);
    });
  });

  group('VerifyEmailView Widget Tests', () {
    late FakeAuthService authService;
    late AuthBloc authBloc;

    setUp(() {
      authService = FakeAuthService();
      authBloc = AuthBloc(authService);
    });

    tearDown(() {
      authBloc.close();
    });

    testWidgets('displays check your school email, email text, buttons and handles resend cooldown',
        (tester) async {
      final state = EmailVerificationRequiredState(
        email: 'student.ui@dbtc-cebu.edu.ph',
        message: 'A verification link has been sent.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: VerifyEmailView(state: state),
          ),
        ),
      );

      // Verify UI text elements
      expect(find.text('Check your school email'), findsOneWidget);
      expect(find.textContaining('student.ui@dbtc-cebu.edu.ph'), findsOneWidget);
      expect(find.text('A verification link has been sent.'), findsOneWidget);
      expect(find.text('I verified my email'), findsOneWidget);
      expect(find.text('Resend'), findsOneWidget);
      expect(find.text('Back to Sign In'), findsOneWidget);

      // Tap Resend -> triggers cooldown
      await tester.tap(find.text('Resend'));
      await tester.pump();

      // Button is now disabled and shows cooldown timer
      expect(find.textContaining('Resend in'), findsOneWidget);

      // Advance time by 1 second
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Resend in'), findsOneWidget);
    });
  });
}
