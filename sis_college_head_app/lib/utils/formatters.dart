import 'package:intl/intl.dart';

/// One way to write terms and dates everywhere in the app.

/// "2026-2027 (1st Sem)" — the same wording the server uses on reports, printouts and the activity log.
String formatTermLabel(String schoolYear, int? semester) {
  final sem = switch (semester) {
    1 => '1st Sem',
    2 => '2nd Sem',
    3 => 'Summer',
    _ => null,
  };
  return sem == null ? schoolYear : '$schoolYear ($sem)';
}

final _date = DateFormat('MMM d, yyyy');
final _dateTime = DateFormat('MMM d, yyyy · h:mm a');

/// "Nov 4, 2026", in local time.
String formatDate(DateTime d) => _date.format(d.toLocal());

/// "Nov 4, 2026 · 9:30 AM", in local time.
String formatDateTime(DateTime d) => _dateTime.format(d.toLocal());
