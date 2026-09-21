import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/utils/error_handler.dart';

void main() {
  group('getFriendlyErrorMessage', () {
    test('returns session expired for 401', () {
      final error = ApiException(statusCode: 401, message: 'Unauthorized');
      expect(getFriendlyErrorMessage(error), 'Your session has expired. Please sign in again.');
    });

    test('returns access denied for 403', () {
      final error = ApiException(statusCode: 403, message: 'Forbidden');
      expect(getFriendlyErrorMessage(error), 'Access denied — contact your administrator.');
    });

    test('returns server error message for 500', () {
      final error = ApiException(statusCode: 500, message: 'Internal Server Error');
      expect(getFriendlyErrorMessage(error), 'Something went wrong on our end. Please try again, or contact support if this keeps happening.');
    });
  });
}
