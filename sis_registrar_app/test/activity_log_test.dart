import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/activity_log_models.dart';
import 'package:sis_registrar_app/repositories/activity_log_repository.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';
import 'package:sis_registrar_app/views/widgets/activity_log_browser.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _entry(int i, {String action = 'LOADS_FINALIZED', String? student = 'Ana Cruz'}) => {
      'id': 'e$i',
      'occurredAt': '2026-11-04T01:0$i:00Z',
      'actorName': 'Rita Reg',
      'actorRole': 2,
      'action': action,
      'studentUserId': student == null ? null : 'u1',
      'studentName': student,
      'termLabel': '2026-2027 (1st Semester)',
      'summary': 'Finalized $i subject(s)',
    };

void main() {
  test('entry parses UTC time to local and labels the action and role', () {
    final e = ActivityLogEntry.fromJson(_entry(1));
    expect(e.occurredAt.isUtc, isFalse);
    expect(e.occurredAt.toUtc(), DateTime.utc(2026, 11, 4, 1, 1));
    expect(e.actionLabel, 'Loads finalized');
    expect(e.actorRoleName, 'Registrar');
    expect(ActivityLogEntry.fromJson({..._entry(1), 'occurredAt': '2026-11-04T01:01:00'}).occurredAt.toUtc(),
        DateTime.utc(2026, 11, 4, 1, 1));
  });

  test('page count rounds up', () {
    expect(const ActivityLogPage(items: [], page: 1, pageSize: 50, totalCount: 101).pageCount, 3);
    expect(const ActivityLogPage(items: [], page: 1, pageSize: 50, totalCount: 0).pageCount, 1);
  });

  test('repository sends filters; "to" covers the whole day', () async {
    late Uri uri;
    final repo = ActivityLogRepository(FakeAuthService(), client: MockClient((req) async {
      uri = req.url;
      return http.Response(jsonEncode({'items': [], 'page': 2, 'pageSize': 25, 'totalCount': 0}), 200);
    }));

    await repo.search(
        from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 3), action: 'CREDIT_ADDED', studentId: 'u1', page: 2, pageSize: 25);

    expect(uri.path, '/api/activity-log');
    final q = uri.queryParameters;
    expect(q['action'], 'CREDIT_ADDED');
    expect(q['studentId'], 'u1');
    expect(q['page'], '2');
    expect(DateTime.parse(q['from']!).toLocal(), DateTime(2026, 11, 1));
    expect(DateTime.parse(q['to']!).toLocal(), DateTime(2026, 11, 4));
  });

  test('Activity log is a tab of Reports, not its own menu item', () {
    final titles = MainLayoutView.buildNavItems(role: 2, roleName: 'Registrar').map((i) => i['title']);
    expect(titles, contains('Reports'));
    expect(titles, isNot(contains('Activity log')));
  });

  group('browser', () {
    late List<Map<String, String>> requests;
    late int total;

    setUp(() async {
      await getIt.reset();
      requests = [];
      total = 3;
      getIt.registerSingleton<ActivityLogRepository>(ActivityLogRepository(FakeAuthService(),
          client: MockClient((req) async {
            requests.add(req.url.queryParameters);
            final page = int.parse(req.url.queryParameters['page']!);
            return http.Response(
                jsonEncode({
                  'items': total == 0 ? [] : [_entry(page), _entry(page + 5, action: 'TEACHER_ASSIGNED', student: null)],
                  'page': page,
                  'pageSize': 2,
                  'totalCount': total,
                }),
                200);
          })));
    });

    tearDown(() async => getIt.reset());

    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
      await tester.pumpAndSettle();
    }

    testWidgets('page shows entries with who, student and term, and pages forward', (tester) async {
      await pump(tester, const ActivityLogBrowser());

      expect(find.text('Loads finalized'), findsOneWidget);
      expect(find.text('By Rita Reg (Registrar) · Ana Cruz · 2026-2027 (1st Semester)'), findsOneWidget);
      expect(find.text('3 entries · page 1 of 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('activity_next_page')));
      await tester.pumpAndSettle();
      expect(requests.last['page'], '2');
      expect(find.text('Finalized 2 subject(s)'), findsOneWidget);
    });

    testWidgets('choosing an action filters and returns to page 1', (tester) async {
      await pump(tester, const ActivityLogBrowser());

      await tester.tap(find.byKey(const ValueKey('activity_action_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Credit added').last);
      await tester.pumpAndSettle();

      expect(requests.last['action'], 'CREDIT_ADDED');
      expect(requests.last['page'], '1');
      expect(find.byKey(const ValueKey('activity_clear_filters')), findsOneWidget);
    });

    testWidgets('student history asks only for that student and hides the student name', (tester) async {
      await pump(tester, const StudentHistoryDialog(studentId: 'u1', studentName: 'Ana Cruz'));

      expect(requests.single['studentId'], 'u1');
      expect(find.text('History — Ana Cruz'), findsOneWidget);
      expect(find.text('By Rita Reg (Registrar) · 2026-2027 (1st Semester)'), findsWidgets);
    });

    testWidgets('empty log says so', (tester) async {
      total = 0;
      await pump(tester, const ActivityLogBrowser());
      expect(find.text('No activity recorded yet.'), findsOneWidget);
    });
  });
}
