import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/class_models.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/repositories/class_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/utils/study_load_pdf.dart';
import 'package:sis_registrar_app/views/widgets/student_study_load_dialog.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _load(String code, String status, {double units = 3}) => {
      'studyLoadId': 'sl-$code',
      'subjectCode': code,
      'subjectTitle': '$code title',
      'className': 'BSIT 1A',
      'teacherName': 'Ben Basiced',
      'loadStatus': status,
      'termLabel': '2026-2027 (1st Sem)',
      'units': units,
      'schedules': [
        {'scheduleId': 's1', 'classId': 'c1', 'daysOfWeek': 'M/W/F', 'startTime': '08:00:00', 'endTime': '09:00:00', 'room': 'R101'}
      ],
    };

ClassRosterItemModel _model(String code, String status, {double units = 3}) =>
    ClassRosterItemModel.fromJson(_load(code, status, units: units));

/// Uncompressed PDF content streams keep the text as literal strings.
String _text(Uint8List bytes) => latin1.decode(bytes);

void main() {
  test('roster model parses units and schedules', () {
    final m = _model('IT 101', 'Enrolled', units: 3);
    expect(m.units, 3);
    expect(m.schedules.single.room, 'R101');
  });

  test('print data keeps Enrolled subjects only, sorted, and totals units', () {
    final data = StudyLoadPrintData(
      studentName: 'Ana Cruz',
      termLabel: 'T',
      loads: [_model('IT 102', 'Enrolled'), _model('IT 101', 'Enrolled', units: 2), _model('GEC 101', 'Pending'), _model('PE 101', 'Dropped')],
    );
    expect(data.loads.map((l) => l.subjectCode), ['IT 101', 'IT 102']);
    expect(data.totalUnits, 5);
  });

  test('pdfSafe replaces dashes and characters the PDF font cannot show', () {
    expect(pdfSafe('8:00 AM – 9:00 AM'), '8:00 AM - 9:00 AM');
    expect(pdfSafe('Peña'), 'Peña');
    expect(pdfSafe('日本'), '??');
  });

  test('PDF contains the student, subjects, schedule and total', () async {
    final data = StudyLoadPrintData(
      studentName: 'Ana Cruz',
      lrn: '123456789012',
      programCode: 'BSIT',
      yearLevel: 1,
      termLabel: '2026-2027 (1st Sem)',
      loads: [_model('IT 101', 'Enrolled'), _model('THEO 101', 'Enrolled'), _model('GEC 101', 'Pending')],
    );

    final bytes = await buildStudyLoadPdf(data, compress: false);
    final text = _text(bytes);

    expect(text.startsWith('%PDF'), isTrue);
    // Each word is drawn separately, so look for single words.
    for (final s in ['(Ana)', '(Cruz)', '(123456789012)', '(BSIT)', '(Year)', '(THEO)', '(R101)', '(Basiced)', '(Total)', '(6)']) {
      expect(text, contains(s), reason: s);
    }
    expect(text, isNot(contains('(GEC)')));
  });

  group('Print button', () {
    late List<String> printed;

    setUp(() async {
      await getIt.reset();
      printed = [];
      printPdf = (bytes, name) async => printed.add(name);
    });

    tearDown(() async => getIt.reset());

    Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> loads) async {
      getIt.registerSingleton<ClassRepository>(ClassRepository(
        FakeAuthService(),
        MockClient((req) async => req.url.path.startsWith('/api/studyloads/student/')
            ? http.Response(jsonEncode(loads), 200)
            : http.Response('Not Found', 404)),
      ));
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StudentStudyLoadDialog(
            student: UserSearchResultModel(userId: 'u1', email: 'a@x.com', role: 5, firstname: 'Ana', lastname: 'Cruz'),
            termId: 't1',
            termLabel: '2026-2027 (1st Sem)',
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('prints when the student has enrolled subjects', (tester) async {
      await pump(tester, [_load('IT 101', 'Enrolled')]);

      await tester.tap(find.byKey(const ValueKey('print_study_load_button')));
      await tester.pumpAndSettle();

      expect(printed, ['StudyLoad_Ana_Cruz.pdf']);
    });

    testWidgets('is disabled when nothing is enrolled yet', (tester) async {
      await pump(tester, [_load('IT 101', 'Pending')]);

      final button = tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('print_study_load_button')));
      expect(button.onPressed, isNull);
    });
  });
}
