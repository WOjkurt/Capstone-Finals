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

class UnauthenticatedState extends AuthState {
  final String? errorMessage;
  UnauthenticatedState({this.errorMessage});
}

/// Roles allowed into the College Head Portal: 1 = Admin, 6 = College Head.
bool isAllowedRole(int role) => role == 1 || role == 6;

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthService _authService;

  AuthBloc(this._authService) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAuthCheckRequested(
      AuthCheckRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final userInfo = await _authService.fetchCurrentUserInfo();
      if (userInfo == null) {
        emit(UnauthenticatedState());
        return;
      }

      final role = userInfo['role'] as int? ?? 0;
      final roleName = userInfo['roleName'] as String? ?? 'User';
      final userId = userInfo['userId'] as String? ?? '';
      final email = userInfo['email'] as String? ?? '';

      if (!isAllowedRole(role)) {
        await _authService.signOut();
        emit(AccessDeniedState(
            'Access denied. Your account role ($roleName) is not authorized to access the College Head Portal.',
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
      final userId = userInfo['userId'] as String? ?? '';
      final email = userInfo['email'] as String? ?? event.email;

      if (!isAllowedRole(role)) {
        await _authService.signOut();
        emit(AccessDeniedState(
            'Access denied. Your account role ($roleName) is not authorized to access the College Head Portal.',
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
      final msg = getFriendlyErrorMessage(e, st);
      emit(UnauthenticatedState(errorMessage: msg));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    await _authService.signOut();
    emit(UnauthenticatedState());
  }
}
