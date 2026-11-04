import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_teacher_app/blocs/auth_bloc.dart';
import 'package:sis_teacher_app/blocs/classes_bloc.dart';
import 'package:sis_teacher_app/blocs/faculty_bloc.dart';
import 'package:sis_teacher_app/blocs/grade_corrections_bloc.dart';
import 'package:sis_teacher_app/blocs/grades_bloc.dart';
import 'package:sis_teacher_app/blocs/program_overview_bloc.dart';
import 'package:sis_teacher_app/injection.dart';
import 'package:sis_teacher_app/services/auth_service.dart';
import 'package:sis_teacher_app/theme/app_theme.dart';
import 'package:sis_teacher_app/views/main_layout_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t', 'Content-Type': 'application/json'};
  @override
  Future<String?> getToken() async => 't';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<http.Response> _api(http.Request req) async => http.Response(jsonEncode(<Object>[]), 200);

/// Builds the real app around [MainLayoutView] with fake data. Shared with test_screens/.
Widget buildTeacherApp(AuthenticatedState auth) => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc(getIt<AuthService>())),
        BlocProvider<ClassesBloc>(create: (_) => getIt<ClassesBloc>()),
        BlocProvider<GradesBloc>(create: (_) => getIt<GradesBloc>()),
        BlocProvider<GradeCorrectionsBloc>(create: (_) => getIt<GradeCorrectionsBloc>()),
        BlocProvider<ProgramOverviewBloc>(create: (_) => getIt<ProgramOverviewBloc>()),
        BlocProvider<FacultyBloc>(create: (_) => getIt<FacultyBloc>()),
      ],
      child: MaterialApp(debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme, home: MainLayoutView(auth: auth)),
    );

void main() {
  final teacher = AuthenticatedState(email: 't@x.com', role: 3, roleName: 'Teacher', userId: 't1', fullName: 'Ben Teach');
  final head = AuthenticatedState(email: 'h@x.com', role: 4, roleName: 'Program Head', userId: 'h1');

  test('teachers get 3 pages; Program Heads get 2 more, set apart by a gap', () {
    final t = MainLayoutView.buildNavItems(role: 3, roleName: 'Teacher');
    expect(t.map((i) => i['title']), ['My Classes', 'Grades', 'Grade Corrections']);

    final h = MainLayoutView.buildNavItems(role: 4, roleName: 'Program Head');
    expect(h.map((i) => i['title']), ['My Classes', 'Grades', 'Grade Corrections', 'Program Overview', 'Faculty']);
    expect(h.firstWhere((i) => i['title'] == 'Program Overview')['gapBefore'], isTrue);
  });

  test('the menu shows the name, or the email when no name is on file', () {
    expect(teacher.displayName, 'Ben Teach');
    expect(head.displayName, 'h@x.com');
  });

  Future<void> pump(WidgetTester tester, AuthenticatedState auth, {double width = 1440}) async {
    await getIt.reset();
    setupLocator();
    getIt.allowReassignment = true;
    getIt.registerSingleton<AuthService>(FakeAuthService());
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildTeacherApp(auth));
    await tester.pumpAndSettle();
  }

  testWidgets('full menu: page links, name and sign out only', (tester) async {
    await http.runWithClient(() async {
      await pump(tester, teacher);

      expect(find.byKey(const ValueKey('full_sidebar')), findsOneWidget);
      for (final t in ['My Classes', 'Grades', 'Grade Corrections']) {
        expect(find.byKey(ValueKey('nav_$t')), findsOneWidget, reason: t);
      }
      expect(find.text('Ben Teach'), findsOneWidget);
      expect(find.text('t@x.com'), findsNothing);
      expect(find.byKey(const ValueKey('sign_out_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav_Grades')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page_refresh_button')), findsWidgets);
    }, () => MockClient(_api));
  });

  testWidgets('laptop width shows icons only', (tester) async {
    await http.runWithClient(() async {
      await pump(tester, head, width: 1200);

      expect(find.byKey(const ValueKey('compact_sidebar')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_Faculty')), findsOneWidget);
    }, () => MockClient(_api));
  });
}
