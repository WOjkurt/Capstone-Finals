import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/utils/phone_zip.dart';

void main() {
  test('cleanPhone writes numbers the same way as the API', () {
    expect(cleanPhone('+63 917 123 4567'), '09171234567');
    expect(cleanPhone('0917-123-4567'), '09171234567');
    expect(cleanPhone('639171234567'), '09171234567');
    expect(cleanPhone('(032) 253-1234'), '0322531234');
    expect(cleanPhone(' abc '), 'abc');
  });

  test('mobileError', () {
    expect(mobileError('09171234567'), isNull);
    expect(mobileError('+63 917 123 4567'), isNull);
    expect(mobileError('0917'), isNotNull);
    expect(mobileError('0322531234'), isNotNull);
    expect(mobileError(''), isNull);
  });

  test('phoneError accepts mobile, landline or N/A', () {
    expect(phoneError('09171234567'), isNull);
    expect(phoneError('(032) 253-1234'), isNull);
    expect(phoneError('n/a'), isNull);
    expect(phoneError('12345'), isNotNull);
  });

  test('zipError', () {
    expect(zipError('6000'), isNull);
    expect(zipError('60 00'), isNull);
    expect(zipError('600'), isNotNull);
    expect(zipError('60a0'), isNotNull);
  });
}
