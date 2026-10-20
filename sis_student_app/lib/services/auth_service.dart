import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../utils/error_handler.dart';

class EmailNotVerifiedException implements Exception {
  final String email;
  EmailNotVerifiedException(this.email);

  @override
  String toString() => 'EmailNotVerifiedException(email: $email)';
}

class AuthService {
  final FirebaseAuth _auth;
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get userStream => _auth.authStateChanges();

  Future<String?> getToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<UserCredential> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.sendEmailVerification();
    return cred;
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> reloadUserAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await refreshed.getIdToken(true);
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>?> signInAndVerify(
      String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final user = cred.user;
    if (user != null && !user.emailVerified) {
      throw EmailNotVerifiedException(user.email ?? email);
    }
    final token = await user?.getIdToken();

    final response = await http.get(
      Uri.parse('$baseUrl/api/Me'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Failed to fetch user info: ${response.body}',
    );
  }

  Future<Map<String, dynamic>?> fetchCurrentUserInfo() async {
    final token = await getToken();
    if (token == null) return null;
    final response = await http.get(
      Uri.parse('$baseUrl/api/Me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      message: 'Failed to fetch user info: ${response.body}',
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null) return {};
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }
}
