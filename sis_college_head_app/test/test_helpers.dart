import 'package:firebase_auth/firebase_auth.dart';
import 'package:sis_college_head_app/services/auth_service.dart';

// Mock auth service (no Firebase dependency)
class MockAuthService implements AuthService {
  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  User? get currentUser => null;

  @override
  Stream<User?> get userStream => const Stream.empty();

  @override
  Future<String?> getToken() async => 'test-token';

  @override
  Future<Map<String, String>> getAuthHeaders() async => {
        'Authorization': 'Bearer test-token',
        'Content-Type': 'application/json',
      };

  @override
  Future<Map<String, dynamic>?> signInAndVerify(
          String email, String password) async =>
      null;

  @override
  Future<Map<String, dynamic>?> fetchCurrentUserInfo() async => null;

  @override
  Future<void> signOut() async {}
}
