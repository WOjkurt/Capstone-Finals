import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/blocs/applications_bloc.dart';
import 'package:sis_registrar_app/blocs/auth_bloc.dart';
import 'package:sis_registrar_app/blocs/clearance_bloc.dart';
import 'package:sis_registrar_app/blocs/dashboard_bloc.dart';
import 'package:sis_registrar_app/blocs/link_accounts_bloc.dart';
import 'package:sis_registrar_app/blocs/responses_bloc.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/blocs/staff_bloc.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/views/clearance_view.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {
    'Authorization': 'Bearer t',
  };
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _requests = <String>[];

/// How long the fake server takes to answer a student search.
var _searchDelay = Duration.zero;

Future<http.Response> _api(http.Request req) async {
  final path = req.url.path;
  _requests.add('$path?${req.url.query}');
  Object body = <Object>[];
  if (path.endsWith('/api/AcademicTerms')) {
    body = [
      {
        'termID': 't1',
        'schoolYear': '2026-2027',
        'semester': 1,
        'isActive': true,
      },
      {
        'termID': 't0',
        'schoolYear': '2025-2026',
        'semester': 2,
        'isActive': false,
      },
    ];
  }
  if (path.endsWith('/api/activity-log'))
    body = {'items': [], 'page': 1, 'pageSize': 50, 'totalCount': 0};
  if (path.endsWith('/api/students/search')) {
    if (_searchDelay > Duration.zero) await Future<void>.delayed(_searchDelay);
    body = [
      {
        'userId': 'u1',
        'firstname': 'Ana',
        'lastname': 'Cruz',
        'email': 'ana@x.com',
        'role': 5,
      },
    ];
  }
  if (path.contains('/api/studyloads/pending-summary')) {
    body = [
      {'userId': 'u9', 'fullName': 'Pat', 'pendingCount': 2, 'pendingUnits': 6},
    ];
  }
  return http.Response(jsonEncode(body), 200);
}

Future<ClearanceBloc> _pumpApp(WidgetTester tester, {double width = 1440}) async {
  await getIt.reset();
  setupLocator();
  getIt.allowReassignment = true;
  getIt.registerSingleton<AuthService>(FakeAuthService());
  // The menu picks its layout from the window size, so set the window, not just the surface.
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final clearance = getIt<ClearanceBloc>();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc(getIt<AuthService>())),
        BlocProvider<DashboardBloc>(create: (_) => getIt<DashboardBloc>()),
        BlocProvider<ResponsesBloc>(create: (_) => getIt<ResponsesBloc>()),
        BlocProvider<ApplicationsBloc>(
          create: (_) => getIt<ApplicationsBloc>(),
        ),
        BlocProvider<LinkAccountsBloc>(
          create: (_) => getIt<LinkAccountsBloc>(),
        ),
        BlocProvider<ClearanceBloc>.value(value: clearance),
        BlocProvider<SetupBloc>(create: (_) => getIt<SetupBloc>()),
        BlocProvider<StaffBloc>(create: (_) => getIt<StaffBloc>()),
      ],
      child: MaterialApp(
        home: MainLayoutView(
          auth: AuthenticatedState(
            email: 'r@x.com',
            role: 2,
            roleName: 'Registrar',
            userId: 'r1',
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return clearance;
}

void main() {
  setUp(() {
    _requests.clear();
    _searchDelay = Duration.zero;
  });

  testWidgets('a calm menu: 6 page links and badges only; Ctrl+K jumps to the Students search', (tester) async {
    await http.runWithClient(() async {
      final clearance = await _pumpApp(tester);

      final titles = MainLayoutView.buildNavItems(role: 2, roleName: 'Registrar').map((i) => i['title']).toList();
      expect(titles, ['Dashboard', 'Admissions', 'Students', 'Pending loads', 'Reports', 'Setup']);
      for (final t in titles) {
        expect(find.byKey(ValueKey('nav_$t')), findsOneWidget, reason: t);
      }
      // No search box, term picker or section labels in the menu.
      final menu = find.byKey(const ValueKey('full_sidebar'));
      expect(find.descendant(of: menu, matching: find.byType(TextField)), findsNothing);
      expect(find.descendant(of: menu, matching: find.byType(DropdownButtonFormField<String>)), findsNothing);
      expect(find.text('STUDENTS'), findsNothing);
      expect(find.byKey(const ValueKey('nav_badge_Pending loads')), findsOneWidget);

      // Ctrl+K opens Students with the cursor in its search box.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Find a student'), findsOneWidget);
      final search = find.descendant(of: find.byType(ClearanceView), matching: find.byType(TextField)).first;
      expect(tester.widget<TextField>(search).focusNode!.hasFocus, isTrue);

      await tester.enterText(search, 'ana');
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect((clearance.state as ClearanceStateData).searchResults.single.fullName, 'Ana Cruz');
    }, () => MockClient(_api));
  });

  testWidgets(
    'one term for the whole app: changing it on one page reloads Pending loads and Reports',
    (tester) async {
      await http.runWithClient(() async {
        await _pumpApp(tester);
        expect(
          _requests.any(
            (r) =>
                r.contains('/api/studyloads/pending-summary') &&
                r.contains('termId=t1'),
          ),
          isTrue,
        );
        expect(
          _requests.any(
            (r) =>
                r.contains('/api/reports/enrollment-summary') &&
                r.contains('termId=t1'),
          ),
          isTrue,
        );

        _requests.clear();
        await tester.tap(find.byType(DropdownButtonFormField<String>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('2025-2026 (2nd Sem)').last);
        await tester.pumpAndSettle();

        expect(
          _requests.any(
            (r) =>
                r.contains('/api/studyloads/pending-summary') &&
                r.contains('termId=t0'),
          ),
          isTrue,
        );
        expect(
          _requests.any(
            (r) =>
                r.contains('/api/reports/enrollment-summary') &&
                r.contains('termId=t0'),
          ),
          isTrue,
        );
      }, () => MockClient(_api));
    },
  );

  testWidgets('laptop width shows an icons-only menu with dots for waiting items', (tester) async {
    await http.runWithClient(() async {
      await _pumpApp(tester, width: 1200);

      expect(find.byKey(const ValueKey('compact_sidebar')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_dot_Pending loads')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav_Students')));
      await tester.pumpAndSettle();
      expect(find.text('Find a student'), findsOneWidget);
    }, () => MockClient(_api));
  });

  testWidgets('Admissions has the three steps as tabs; dashboard links open the right tab', (tester) async {
    await http.runWithClient(() async {
      await _pumpApp(tester);

      await tester.tap(find.byKey(const ValueKey('nav_Admissions')));
      await tester.pumpAndSettle();
      final tabs = find.byKey(const ValueKey('admissions_tabs'));
      for (final t in ['1. Form responses', '2. Applications', '3. Create logins']) {
        expect(find.descendant(of: tabs, matching: find.textContaining(t)), findsOneWidget, reason: t);
      }

      // Dashboard "See all" (recent activity) opens Reports on its Activity log tab.
      await tester.tap(find.byKey(const ValueKey('nav_Dashboard')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('activity_action_dropdown')), findsOneWidget);
    }, () => MockClient(_api));
  });

  test('the menu shows the name, or the email when no name is on file', () {
    expect(AuthenticatedState(email: 'r@x.com', role: 2, roleName: 'Registrar', userId: 'r1', fullName: 'Rita Reg').displayName,
        'Rita Reg');
    expect(AuthenticatedState(email: 'r@x.com', role: 2, roleName: 'Registrar', userId: 'r1').displayName, 'r@x.com');
    expect(AuthenticatedState(email: 'r@x.com', role: 2, roleName: 'Registrar', userId: 'r1', fullName: '  ').displayName,
        'r@x.com');
  });

  testWidgets('typing is never cut off: a slow, out-of-date reply cannot rewrite the box', (tester) async {
    await http.runWithClient(() async {
      await _pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav_Students')));
      await tester.pumpAndSettle();
      // Each search takes longer than the gap between keystrokes, so replies land
      // after the person has already typed more.
      _searchDelay = const Duration(milliseconds: 600);

      final search = find
          .descendant(of: find.byType(ClearanceView), matching: find.byType(TextField))
          .first;
      final field = tester.widget<TextField>(search).controller!;

      // Every value the box ever holds, in order.
      final seen = <String>[];
      field.addListener(() => seen.add(field.text));

      for (final typed in ['a', 'an', 'ana']) {
        await tester.enterText(search, typed);
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // The box only ever grows as the letters are typed. It used to snap back to an
      // older query when a slow reply arrived, which ate whatever had been typed since.
      var longest = '';
      for (final value in seen) {
        expect(value.length, greaterThanOrEqualTo(longest.length),
            reason: 'the box went backwards from "$longest" to "$value": $seen');
        longest = value;
      }
      expect(field.text, 'ana');
    }, () => MockClient(_api));
  });

  testWidgets('a burst of typing sends one search, for the final text', (tester) async {
    await http.runWithClient(() async {
      await _pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('nav_Students')));
      await tester.pumpAndSettle();
      _requests.clear();

      final search = find
          .descendant(of: find.byType(ClearanceView), matching: find.byType(TextField))
          .first;

      // Typing faster than the debounce: only the last one should reach the server.
      for (final typed in ['a', 'an', 'ana']) {
        await tester.enterText(search, typed);
        await tester.pump(const Duration(milliseconds: 80));
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final searches = _requests.where((r) => r.contains('/api/students/search')).toList();
      expect(searches, hasLength(1));
      expect(searches.single, contains('ana'));
    }, () => MockClient(_api));
  });
}
