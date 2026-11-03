import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/injection.dart';
import 'package:sis_college_head_app/models/class_models.dart';
import 'package:sis_college_head_app/repositories/class_repository.dart';
import 'package:sis_college_head_app/views/widgets/class_schedule_dialog.dart';
import 'test_helpers.dart';

const _class = ClassModel(
  classId: 'c2',
  subjectId: 's2',
  subjectCode: 'THEO 101A',
  termId: 'term-active',
  className: 'BSME 1A',
  isMinor: true,
);

Map<String, dynamic> _schedule(String id, String days, String start, String end, String room) => {
      'scheduleID': id,
      'classID': 'c2',
      'daysOfWeek': days,
      'startTime': start,
      'endTime': end,
      'room': room,
    };

void main() {
  group('ClassRepository schedule calls', () {
    test('createSchedule POSTs to /api/classes/{id}/schedules with HH:mm:ss times', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{}', 201);
      });

      await ClassRepository(MockAuthService(), client).createSchedule(
          classId: 'c2', daysOfWeek: 'M/W/F', startTime: '08:00', endTime: '09:30', room: 'R101');

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/classes/c2/schedules');
      expect(jsonDecode(captured!.body), {
        'classID': 'c2',
        'daysOfWeek': 'M/W/F',
        'startTime': '08:00:00',
        'endTime': '09:30:00',
        'room': 'R101',
      });
    });

    test('updateSchedule PUTs and deleteSchedule DELETEs /api/ClassSchedules/{id}', () async {
      final seen = <String>[];
      final client = MockClient((req) async {
        seen.add('${req.method} ${req.url.path}');
        return http.Response('{}', 200);
      });
      final repo = ClassRepository(MockAuthService(), client);

      await repo.updateSchedule(
          scheduleId: 'sch1', classId: 'c2', daysOfWeek: 'T/TH', startTime: '10:00', endTime: '11:00', room: 'R102');
      await repo.deleteSchedule('sch1');

      expect(seen, ['PUT /api/ClassSchedules/sch1', 'DELETE /api/ClassSchedules/sch1']);
    });

    test('a clash comes back as the server message', () async {
      final client = MockClient((req) async => http.Response(
          jsonEncode({'message': 'Ben Basiced already teaches THEO 101A (BSIT 1A) M/W/F 08:00-09:00 this term.'}),
          409));

      expect(
        () => ClassRepository(MockAuthService(), client).createSchedule(
            classId: 'c2', daysOfWeek: 'M', startTime: '08:00', endTime: '09:00', room: 'R1'),
        throwsA(predicate((e) => e.toString().contains('already teaches'))),
      );
    });
  });

  group('ClassScheduleDialog', () {
    late List<Map<String, dynamic>> serverSchedules;
    late List<http.Request> writes;
    http.Response Function(http.Request req)? onWrite;

    setUp(() async {
      serverSchedules = [_schedule('sch1', 'M/W/F', '08:00:00', '09:00:00', 'R101')];
      writes = [];
      onWrite = null;
      final client = MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/api/classes/c2/schedules') {
          return http.Response(jsonEncode(serverSchedules), 200);
        }
        writes.add(req);
        return onWrite?.call(req) ?? http.Response('{}', req.method == 'POST' ? 201 : 200);
      });
      await getIt.reset();
      getIt.registerSingleton<ClassRepository>(ClassRepository(MockAuthService(), client));
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: ClassScheduleDialog(classItem: _class)),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> pickTime(WidgetTester tester, String label, String shown) async {
      await tester.tap(find.byWidgetPredicate(
          (w) => w is DropdownButtonFormField<String> && w.key.toString().contains('${label}_time')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(shown).last);
      await tester.pumpAndSettle();
    }

    testWidgets('lists the current schedule', (tester) async {
      await pump(tester);

      expect(find.text('M/W/F 8:00 AM – 9:00 AM · R101'), findsOneWidget);
    });

    testWidgets('refuses to save without days, and when end is not after start', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('save_schedule_button')));
      await tester.pumpAndSettle();
      expect(find.text('Pick at least one day.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('day_T')));
      await pickTime(tester, 'start', '10:00 AM');
      await pickTime(tester, 'end', '9:30 AM');
      await tester.enterText(find.byKey(const ValueKey('room_field')), 'R102');
      await tester.tap(find.byKey(const ValueKey('save_schedule_button')));
      await tester.pumpAndSettle();

      expect(find.text('End time must be after start time.'), findsOneWidget);
      expect(writes, isEmpty);
    });

    testWidgets('adds a meeting time in standard day order, then reloads', (tester) async {
      await pump(tester);

      // Tap TH before T to check the saved order is still "T/TH".
      await tester.tap(find.byKey(const ValueKey('day_TH')));
      await tester.tap(find.byKey(const ValueKey('day_T')));
      await pickTime(tester, 'start', '10:00 AM');
      await pickTime(tester, 'end', '11:30 AM');
      await tester.enterText(find.byKey(const ValueKey('room_field')), ' R102 ');
      serverSchedules.add(_schedule('sch2', 'T/TH', '10:00:00', '11:30:00', 'R102'));
      await tester.tap(find.byKey(const ValueKey('save_schedule_button')));
      await tester.pumpAndSettle();

      expect(writes.single.method, 'POST');
      final body = jsonDecode(writes.single.body) as Map<String, dynamic>;
      expect(body['daysOfWeek'], 'T/TH');
      expect(body['startTime'], '10:00:00');
      expect(body['endTime'], '11:30:00');
      expect(body['room'], 'R102');
      expect(find.text('T/TH 10:00 AM – 11:30 AM · R102'), findsOneWidget);
    });

    testWidgets('shows the teacher clash message from the server', (tester) async {
      onWrite = (req) => http.Response(
          jsonEncode({'message': 'Ben Basiced already teaches THEO 101A (BSIT 1A) M/W/F 08:00-09:00 this term.'}),
          409);
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('day_M')));
      await pickTime(tester, 'start', '8:00 AM');
      await pickTime(tester, 'end', '9:00 AM');
      await tester.enterText(find.byKey(const ValueKey('room_field')), 'R202');
      await tester.tap(find.byKey(const ValueKey('save_schedule_button')));
      await tester.pumpAndSettle();

      expect(find.textContaining('already teaches THEO 101A (BSIT 1A)'), findsOneWidget);
    });

    testWidgets('Edit fills the form and saving sends PUT', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit meeting time'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('room_field')), 'R303');
      await tester.tap(find.byKey(const ValueKey('save_schedule_button')));
      await tester.pumpAndSettle();

      expect(writes.single.method, 'PUT');
      expect(writes.single.url.path, '/api/ClassSchedules/sch1');
      final body = jsonDecode(writes.single.body) as Map<String, dynamic>;
      expect(body['daysOfWeek'], 'M/W/F');
      expect(body['startTime'], '08:00:00');
      expect(body['room'], 'R303');
    });

    testWidgets('Delete asks first, then sends DELETE', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Delete schedule?'), findsOneWidget);
      serverSchedules.clear();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(writes.single.method, 'DELETE');
      expect(find.text('No schedule yet.'), findsOneWidget);
    });
  });
}
