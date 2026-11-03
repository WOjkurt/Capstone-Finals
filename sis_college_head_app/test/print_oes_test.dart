import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/injection.dart';
import 'package:sis_college_head_app/models/class_models.dart';
import 'package:sis_college_head_app/models/grading_models.dart';
import 'package:sis_college_head_app/repositories/class_repository.dart';
import 'package:sis_college_head_app/utils/study_load_pdf.dart';
import 'package:sis_college_head_app/views/widgets/student_load_dialog.dart';

import 'test_helpers.dart';

Map<String, dynamic> _load(String code, String status) => {
      'studyLoadId': 'sl-$code',
      'subjectCode': code,
      'subjectTitle': '$code title',
      'className': 'BSIT 1A',
      'loadStatus': status,
      'termLabel': 'T',
      'units': 3,
      'schedules': [
        {'daysOfWeek': 'M/W', 'startTime': '08:00:00', 'endTime': '09:30:00', 'room': 'R101'}
      ],
    };

const _student = UserSearchResultModel(
    userId: 'u1', firstname: 'Ana', lastname: 'Cruz', email: 'a@x.com', role: 5, programCode: 'BSIT', yearLevel: 1, lrn: '123456789012');

void main() {
  test('roster model parses units and schedules', () {
    final m = ClassRosterItemModel.fromJson(_load('IT 101', 'Enrolled'));
    expect(m.units, 3);
    expect(m.schedules.single.room, 'R101');
  });

  test('enrollment sheet has three copies with Enrolled subjects only', () async {
    final data = StudyLoadPrintData(
      studentName: 'Ana Cruz',
      termLabel: 'T',
      loads: [ClassRosterItemModel.fromJson(_load('IT 101', 'Enrolled')), ClassRosterItemModel.fromJson(_load('GEC 101', 'Pending'))],
    );
    final text = latin1.decode(await buildStudyLoadPdf(data, compress: false));

    expect(RegExp(r'/Type\s*/Page[^s]').allMatches(text).length, 3);
    expect(text, contains('(ENROLLMENT)'));
    expect(text, contains('(R101)'));
    expect(text, isNot(contains('(GEC)')));
  });

  group('Print Enrollment Sheet button', () {
    late List<String> printed;

    setUp(() async {
      await getIt.reset();
      printed = [];
      printPdf = (bytes, name) async => printed.add(name);
    });

    tearDown(() async => getIt.reset());

    Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> loads) async {
      getIt.registerSingleton<ClassRepository>(ClassRepository(
        MockAuthService(),
        MockClient((req) async => req.url.path.startsWith('/api/studyloads/student/')
            ? http.Response(jsonEncode(loads), 200)
            : http.Response('[]', 200)),
      ));
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: StudentLoadDialog(student: _student, termId: 't1', termLabel: 'T')),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('prints once subjects are enrolled', (tester) async {
      await pump(tester, [_load('IT 101', 'Enrolled')]);

      await tester.tap(find.byKey(const ValueKey('print_oes_button')));
      await tester.pumpAndSettle();

      expect(printed, ['Enrollment_Sheet_Ana_Cruz.pdf']);
    });

    testWidgets('is disabled while the load is still pending', (tester) async {
      await pump(tester, [_load('IT 101', 'Pending')]);

      final button = tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('print_oes_button')));
      expect(button.onPressed, isNull);
    });
  });
}
