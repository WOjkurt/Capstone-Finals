import 'dart:convert';
import 'dart:typed_data';

/// Quotes a CSV cell when it contains a comma, quote or line break.
String csvCell(Object? value) {
  final s = value?.toString() ?? '';
  if (s.contains(RegExp(r'[",\r\n]'))) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

/// Builds a CSV file. Starts with a UTF-8 byte order mark so Excel shows names like "Peña" correctly.
Uint8List buildCsv(List<String> headers, List<List<Object?>> rows) {
  final lines = [
    headers.map(csvCell).join(','),
    for (final r in rows) r.map(csvCell).join(','),
  ];
  return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('${lines.join('\r\n')}\r\n')]);
}
