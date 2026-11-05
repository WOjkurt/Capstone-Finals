import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_student_app/blocs/auth_bloc.dart';
import 'package:sis_student_app/injection.dart';
import 'package:sis_student_app/services/auth_service.dart';
import 'package:sis_student_app/theme/app_theme.dart';
import 'package:sis_student_app/views/main_layout_view.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sample data with long names and titles, so tight phone layouts are really tested.
Future<http.Response> fakeApi(http.Request req) async {
  final path = req.url.path.toLowerCase();
  const term = {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true};
  Object body = <Object>[];
  if (path.endsWith('/api/academicterms/active')) {
    body = term;
  } else if (path.endsWith('/api/academicterms')) {
    body = [term, {'termID': 't0', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false}];
  } else if (path.contains('/api/studyloads/student/')) {
    Map<String, Object?> load(String code, String title, String days, String room) => {
          'studyLoadId': code, 'classId': code, 'subjectCode': code, 'subjectTitle': title, 'units': 3, 'className': 'BTVTED 2A',
          'teacherName': 'Maria Christina Dela Cruz-Santos', 'loadStatus': 'Enrolled', 'termLabel': '2026-2027 (1st Sem)',
          'schedules': [{'scheduleID': 's$code', 'classID': code, 'daysOfWeek': days, 'startTime': '08:00:00', 'endTime': '09:30:00', 'room': room}],
        };
    body = [
      load('TED 305A', 'The Teacher and the Community, School Culture and Organizational Leadership with Focus on the Philippine TVET System', 'M/W/F', 'Shop 2'),
      load('FT 102', 'Engineering Drawing', 'T/TH', 'R101'),
    ];
  } else if (path.contains('/api/gradeclearances/')) {
    body = [
      {'clearanceID': 'c1', 'userID': 'u1', 'termID': 't1', 'termLabel': '2026-2027 (1st Sem)', 'isCleared': true, 'clearedByUserName': 'Rita Reg', 'clearedAt': '2026-10-20T02:00:00Z'},
      {'clearanceID': 'c0', 'userID': 'u1', 'termID': 't0', 'termLabel': '2025-2026 (2nd Sem)', 'isCleared': false},
    ];
  } else if (path.contains('/api/grades/student/')) {
    body = [
      {'gradeId': 'g1', 'subjectCode': 'TED 305A', 'subjectTitle': 'The Teacher and the Community, School Culture and Organizational Leadership', 'className': 'BTVTED 2A', 'units': 3, 'midtermGrade': 1.75, 'finalGrade': 1.5, 'remarks': 1, 'remarksLabel': 'Passed', 'teacherName': 'Maria Christina Dela Cruz-Santos', 'termLabel': '2026-2027 (1st Sem)'},
      {'gradeId': 'g2', 'subjectCode': 'FT 102', 'subjectTitle': 'Engineering Drawing', 'className': 'BTVTED 2A', 'units': 3, 'midtermGrade': 3.0, 'finalGrade': 5.0, 'remarks': 2, 'remarksLabel': 'Failed', 'termLabel': '2026-2027 (1st Sem)'},
    ];
  } else if (path.endsWith('/api/userdetails/me')) {
    body = {
      'userDetailID': 'd1', 'userID': 'u1', 'firstname': 'Ana Maria Concepcion', 'lastname': 'Dela Cruz-Villanueva', 'lrn': '123456789012',
      'programID': 1, 'programCode': 'BTVTED', 'programName': 'Bachelor of Technical-Vocational Teacher Education',
      'studentType': 1, 'studentStatus': 1, 'yearLevel': 2, 'isRegular': false,
    };
  }
  return http.Response(jsonEncode(body), 200);
}

Widget buildStudentApp(AuthenticatedState auth) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: BlocProvider<AuthBloc>(
        create: (_) => AuthBloc(getIt<AuthService>()),
        child: MainLayoutView(auth: auth),
      ),
    );

AuthenticatedState studentAuth({String? fullName = 'Ana Dela Cruz'}) => AuthenticatedState(
      email: 'ana.delacruz.2026@dbtc-cebu.edu.ph', role: 5, roleName: 'Student', userId: 'u1', fullName: fullName);

void main() {
  Future<void> pumpAt(WidgetTester tester, double width, {double height = 800}) async {
    await getIt.reset();
    setupLocator();
    getIt.allowReassignment = true;
    getIt.registerSingleton<AuthService>(FakeAuthService());
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildStudentApp(studentAuth()));
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('phone ($width): bottom menu, and every page fits with long names', (tester) async {
      await http.runWithClient(() async {
        await pumpAt(tester, width);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byKey(const ValueKey('full_sidebar')), findsNothing);
        expect(find.byKey(const ValueKey('sign_out_button')), findsOneWidget);
        for (final label in ['Grades', 'Clearance', 'Profile', 'Schedule']) {
          await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
          await tester.pumpAndSettle();
        }
      }, () => MockClient(fakeApi));
    });
  }

  testWidgets('tablet and laptop show icons only; a wide screen shows the full menu with the name', (tester) async {
    await http.runWithClient(() async {
      await pumpAt(tester, 900);
      expect(find.byKey(const ValueKey('compact_sidebar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_My Grades')));
      await tester.pumpAndSettle();
      expect(find.text('Official midterm and final grades per academic term.'), findsOneWidget);

      await pumpAt(tester, 1440, height: 900);
      expect(find.byKey(const ValueKey('full_sidebar')), findsOneWidget);
      expect(find.text('Ana Dela Cruz'), findsOneWidget);
      expect(find.text('Student Portal'), findsOneWidget);
    }, () => MockClient(fakeApi));
  });

  test('the menu name falls back to the email', () {
    expect(studentAuth(fullName: ' ').displayName, 'ana.delacruz.2026@dbtc-cebu.edu.ph');
  });
}
