/// Same rules as the API (Api/Common/PhoneAndZip.cs), so the student sees the problem before sending.
library;

final _separators = RegExp(r'[\s\-().]');
final _mobile = RegExp(r'^09\d{9}$');
final _landline = RegExp(r'^0[2-8]\d{7,9}$');
final _zip = RegExp(r'^\d{4}$');

/// "+63 917 123 4567" becomes "09171234567". Anything that is not a phone number comes back trimmed.
String cleanPhone(String value) {
  var digits = value.replaceAll(_separators, '');
  if (digits.startsWith('+63')) {
    digits = '0${digits.substring(3)}';
  } else if (digits.startsWith('63') && digits.length == 12) {
    digits = '0${digits.substring(2)}';
  } else if (digits.startsWith('9') && digits.length == 10) {
    digits = '0$digits';
  }
  return _mobile.hasMatch(digits) || _landline.hasMatch(digits) ? digits : value.trim();
}

/// For the student's own mobile number. Empty is left to the "required" check.
String? mobileError(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  return _mobile.hasMatch(cleanPhone(v)) ? null : '11 digits starting with 09, e.g. 09171234567';
}

/// For a parent's or guardian's number: a mobile, a landline with area code, or N/A.
String? phoneError(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty || v.toUpperCase() == 'N/A') return null;
  final c = cleanPhone(v);
  return _mobile.hasMatch(c) || _landline.hasMatch(c) ? null : 'Mobile like 09171234567 or landline like 0322531234';
}

String? zipError(String? value) {
  final v = value?.replaceAll(' ', '') ?? '';
  if (v.isEmpty) return null;
  return _zip.hasMatch(v) ? null : '4 digits, e.g. 6000';
}
