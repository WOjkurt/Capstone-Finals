import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

// Events
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  SignUpRequested(this.email, this.password);
}

class SendVerificationEmailRequested extends AuthEvent {}

class CheckEmailVerifiedRequested extends AuthEvent {}

class LogoutRequested extends AuthEvent {}

// States
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthenticatedState extends AuthState {
  final String email;
  final int role;
  final String roleName;
  final String userId;

  /// From /api/Me; empty when the account has no name on file.
  final String? fullName;

  AuthenticatedState({
    required this.email,
    required this.role,
    required this.roleName,
    required this.userId,
    this.fullName,
  });

  /// What the menu shows: the person's name, or their email when no name is on file.
  String get displayName => (fullName?.trim().isNotEmpty ?? false) ? fullName!.trim() : email;
}

class AccessDeniedState extends AuthState {
  final String message;
  final String email;
  AccessDeniedState(this.message, this.email);
}

class EmailVerificationRequiredState extends AuthState {
  final String email;
  final String? message;
  EmailVerificationRequiredState({required this.email, this.message});
}

class UnauthenticatedState extends AuthState {
  final String? errorMessage;
  UnauthenticatedState({this.errorMessage});
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc(this._authService) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<SignUpRequested>(_onSignUpRequested);
    on<SendVerificationEmailRequested>(_onSendVerificationEmailRequested);
    on<CheckEmailVerifiedRequested>(_onCheckEmailVerifiedRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _authService.currentUser;
      if (user != null && !user.emailVerified) {
        emit(EmailVerificationRequiredState(
          email: user.email ?? '',
          message: 'Please verify your email address, then sign in again.',
        ));
        return;
      }

      final userInfo = await _authService.fetchCurrentUserInfo();
      if (userInfo == null) {
        emit(UnauthenticatedState());
        return;
      }

      final role = userInfo['role'] as int? ?? 0;
      final roleName = userInfo['roleName'] as String? ?? 'User';
      final userId = (userInfo['userId'] ?? userInfo['userID']) as String? ?? '';
      final email = userInfo['email'] as String? ?? '';

      // Role check: 5 = Student
      if (role != 5) {
        await _authService.signOut();
        emit(AccessDeniedState(
            'Access denied. Your account role ($roleName) is not authorized to access the Student Portal.',
            email));
        return;
      }

      emit(AuthenticatedState(
        email: email,
        role: role,
        roleName: roleName,
        userId: userId,
        fullName: userInfo['fullName'] as String?,
      ));
    } catch (e, st) {
      if (e is ApiException && e.statusCode == 403 && e.message.contains('email_not_verified')) {
        emit(EmailVerificationRequiredState(
          email: _authService.currentUser?.email ?? '',
          message: 'Please verify your email address, then sign in again.',
        ));
        return;
      }
      final msg = getFriendlyErrorMessage(e, st);
      emit(UnauthenticatedState(errorMessage: msg));
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userInfo =
          await _authService.signInAndVerify(event.email.trim(), event.password);
      if (userInfo == null) {
        emit(UnauthenticatedState(errorMessage: 'Invalid credentials or failed to fetch account.'));
        return;
      }

      final role = userInfo['role'] as int? ?? 0;
      final roleName = userInfo['roleName'] as String? ?? 'User';
      final userId = (userInfo['userId'] ?? userInfo['userID']) as String? ?? '';
      final email = userInfo['email'] as String? ?? event.email;

      // Role check: 5 = Student
      if (role != 5) {
        await _authService.signOut();
        emit(AccessDeniedState(
            'Access denied. Your account role ($roleName) is not authorized to access the Student Portal.',
            email));
        return;
      }

      emit(AuthenticatedState(
        email: email,
        role: role,
        roleName: roleName,
        userId: userId,
        fullName: userInfo['fullName'] as String?,
      ));
    } on EmailNotVerifiedException catch (e) {
      emit(EmailVerificationRequiredState(
        email: e.email,
        message: 'Please verify your email address, then sign in again.',
      ));
    } catch (e, st) {
      if (e is ApiException && e.statusCode == 403 && e.message.contains('email_not_verified')) {
        emit(EmailVerificationRequiredState(
          email: event.email.trim(),
          message: 'Please verify your email address, then sign in again.',
        ));
        return;
      }
      final msg = getFriendlyErrorMessage(e, st);
      emit(UnauthenticatedState(errorMessage: msg));
    }
  }

  Future<void> _onSignUpRequested(
      SignUpRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final cred = await _authService.signUp(event.email.trim(), event.password);
      emit(EmailVerificationRequiredState(
        email: cred.user?.email ?? event.email.trim(),
        message: 'A verification link has been sent to your email. Please verify your email before continuing.',
      ));
    } catch (e, st) {
      final msg = getFriendlyErrorMessage(e, st);
      emit(UnauthenticatedState(errorMessage: msg));
    }
  }

  Future<void> _onSendVerificationEmailRequested(
      SendVerificationEmailRequested event, Emitter<AuthState> emit) async {
    final email = _authService.currentUser?.email ?? '';
    try {
      await _authService.sendEmailVerification();
      emit(EmailVerificationRequiredState(
        email: email,
        message: 'A fresh verification email has been sent to $email.',
      ));
    } catch (e, st) {
      final msg = getFriendlyErrorMessage(e, st);
      emit(EmailVerificationRequiredState(
        email: email,
        message: msg,
      ));
    }
  }

  Future<void> _onCheckEmailVerifiedRequested(
      CheckEmailVerifiedRequested event, Emitter<AuthState> emit) async {
    final email = _authService.currentUser?.email ?? '';
    emit(AuthLoading());
    try {
      final verified = await _authService.reloadUserAndCheckVerified();
      if (!verified) {
        emit(EmailVerificationRequiredState(
          email: email,
          message: 'Email not verified yet. Please check your inbox and click the verification link.',
        ));
        return;
      }

      final userInfo = await _authService.fetchCurrentUserInfo();
      if (userInfo == null) {
        emit(UnauthenticatedState(errorMessage: 'Failed to fetch account after verification.'));
        return;
      }

      final role = userInfo['role'] as int? ?? 0;
      final roleName = userInfo['roleName'] as String? ?? 'User';
      final userId = (userInfo['userId'] ?? userInfo['userID']) as String? ?? '';
      final userEmail = userInfo['email'] as String? ?? email;

      if (role != 5) {
        await _authService.signOut();
        emit(AccessDeniedState(
            'Access denied. Your account role ($roleName) is not authorized to access the Student Portal.',
            userEmail));
        return;
      }

      emit(AuthenticatedState(
        email: userEmail,
        role: role,
        roleName: roleName,
        userId: userId,
        fullName: userInfo['fullName'] as String?,
      ));
    } catch (e, st) {
      if (e is ApiException && e.statusCode == 403 && e.message.contains('email_not_verified')) {
        emit(EmailVerificationRequiredState(
          email: email,
          message: 'Please verify your email address, then sign in again.',
        ));
        return;
      }
      final msg = getFriendlyErrorMessage(e, st);
      emit(EmailVerificationRequiredState(
        email: email,
        message: msg,
      ));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authService.signOut();
    emit(UnauthenticatedState());
  }
}
