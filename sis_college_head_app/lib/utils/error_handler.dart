import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int? statusCode;
  final String message;

  ApiException({this.statusCode, required this.message});

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

String getFriendlyErrorMessage(dynamic error, [StackTrace? stackTrace]) {
  debugPrint('[App Error] $error');
  if (stackTrace != null) {
    debugPrint('[App Error StackTrace] $stackTrace');
  }

  // 1. ApiException (HTTP status based)
  if (error is ApiException) {
    final code = error.statusCode;
    final body = error.message;

    if (code == 401) {
      // 401 is only for token problems (expired, revoked, invalid, missing).
      if (body.contains('token_expired')) {
        return 'Your session has expired. Please sign in again.';
      }
      return 'Something went wrong. Please try again.';
    }

    if (code == 403) {
      if (body.contains('email_not_verified')) {
        return 'Please verify your email address, then sign in again.';
      }
      if (body.contains('account_not_registered')) {
        return 'Your account is not set up yet. Please contact the school administrator.';
      }
      if (body.contains('account_inactive')) {
        return 'This account is inactive. Please contact the school administrator.';
      }
      return 'Access denied — contact your administrator.';
    }

    if (code != null && code >= 500) {
      return 'Something went wrong on our end. Please try again, or contact support if this keeps happening.';
    }
    // Specific client error (400, 404, 409, 422) with a clean validation message
    if (body.isNotEmpty &&
        !body.contains('<html') &&
        !body.contains('ClientException') &&
        !body.contains('SocketException') &&
        !body.contains('Failed to fetch')) {
      return body;
    }
    return 'Something went wrong. Please try again.';
  }

  // 2. Timeout
  if (error is TimeoutException ||
      error.toString().toLowerCase().contains('timeout')) {
    return 'This is taking longer than usual — please wait a moment and try again.';
  }

  // 3. Network / Connection failures
  if (error is http.ClientException ||
      error.toString().contains('Failed to fetch') ||
      error.toString().contains('ClientException') ||
      error.toString().contains('SocketException') ||
      error.toString().contains('Connection refused') ||
      error.toString().contains('NetworkError') ||
      error.toString().contains('Failed host lookup') ||
      error.toString().contains('network-request-failed')) {
    return "Can't connect right now. Please check your internet connection and try again.";
  }

  // 4. Firebase Authentication exceptions
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-email':
        return 'Invalid email or password. Please check your credentials and try again.';
      case 'network-request-failed':
        return "Can't connect right now. Please check your internet connection and try again.";
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a moment and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact an administrator.';
      default:
        return 'Authentication failed. Please check your credentials and try again.';
    }
  }

  // 5. Server 500 or JSON format parsing error
  if (error is FormatException || error.toString().contains('500')) {
    return 'Something went wrong on our end. Please try again, or contact support if this keeps happening.';
  }

  // 6. Generic Fallback
  return 'Something went wrong. Please try again.';
}
