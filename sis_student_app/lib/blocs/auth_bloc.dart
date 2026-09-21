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

  AuthenticatedState({
    required this.email,
    required this.role,
    required this.roleName,
    required this.userId,
  });
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
