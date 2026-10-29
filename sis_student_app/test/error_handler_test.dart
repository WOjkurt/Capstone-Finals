import 'package:flutter_test/flutter_test.dart';
import 'package:sis_student_app/utils/error_handler.dart';

void main() {
  group('getFriendlyErrorMessage', () {
    test('token_expired 401 returns session expired', () {
      final error = ApiException(
        statusCode: 401,
        message: 'Failed to fetch user info: {"error":"token_expired"}',
      );
      expect(
        getFriendlyErrorMessage(error),
        'Your session has expired. Please sign in again.',
      );
    });

    test('generic 401 (no code) does NOT return session expired', () {
      final error = ApiException(statusCode: 401, message: 'Unauthorized');
      expect(getFriendlyErrorMessage(error), 'Something went wrong. Please try again.');
    });

    test('account_not_registered 403 returns student-specific message', () {
      final error = ApiException(
        statusCode: 403,
        message: 'Failed to fetch user info: {"error":"account_not_registered"}',
      );
      expect(
        getFriendlyErrorMessage(error),
        'Your school email is not registered yet. Please ask the Registrar to register it on your application, then sign in again.',
      );
      // Must NOT say "session expired"
      expect(getFriendlyErrorMessage(error), isNot(contains('session')));
    });

    test('account_inactive 403 returns inactive message', () {
      final error = ApiException(
        statusCode: 403,
        message: 'Failed to fetch user info: {"error":"account_inactive","message":"This account has been disabled."}',
      );
      expect(
        getFriendlyErrorMessage(error),
        'This account is inactive. Please contact the school administrator.',
      );
    });

    test('returns verification message for 403 email_not_verified', () {
      final error = ApiException(
        statusCode: 403,
        message: 'Failed to fetch user info: {"error":"email_not_verified","message":"Please verify your email address, then sign in again."}',
      );
      expect(getFriendlyErrorMessage(error), 'Please verify your email address, then sign in again.');
    });

    test('returns access denied for generic 403', () {
      final error = ApiException(statusCode: 403, message: 'Forbidden');
      expect(getFriendlyErrorMessage(error), 'Access denied — contact your administrator.');
    });

    test('returns server error message for 500', () {
      final error = ApiException(statusCode: 500, message: 'Internal Server Error');
      expect(
        getFriendlyErrorMessage(error),
        'Something went wrong on our end. Please try again, or contact support if this keeps happening.',
      );
    });
  });
}
