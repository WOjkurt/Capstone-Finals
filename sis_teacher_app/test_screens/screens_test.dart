// Renders Teacher app screens with fake API data and real fonts, saving PNGs for design review.
// Run: OUT=/some/dir flutter test test_screens/screens_test.dart   (ROLE=4 for a Program Head)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_teacher_app/blocs/auth_bloc.dart';
import 'package:sis_teacher_app/injection.dart';
import 'package:sis_teacher_app/services/auth_service.dart';

import '../test/menu_test.dart' show FakeAuthService, buildTeacherApp;

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(Future.value(ByteData.view(File('assets/fonts/Inter-$f.ttf').readAsBytesSync().buffer)));
  }
  await inter.load();
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final dir = '$sdk/bin/cache/artifacts/material_fonts';
  ByteData read(String f) => ByteData.view(File('$dir/$f').readAsBytesSync().buffer);
  for (final family in ['Roboto', 'FlutterTest', 'monospace']) {
    final loader = FontLoader(family);
    for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']) {
      loader.addFont(Future.value(read(f)));
    }
    await loader.load();
  }
  await (FontLoader('MaterialIcons')..addFont(Future.value(read('MaterialIcons-Regular.otf')))).load();
}

Future<http.Response> _api(http.Request req) async {
  // The real API routes case-insensitively, and the repositories do not agree on
  // casing, so compare in lower case or routes silently fall through to [].
  final path = req.url.path.toLowerCase();
  Object body = <Object>[];
  if (path.endsWith('/api/academicterms')) {
    body = [
      {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
      {'termID': 't0', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false},
    ];
  } else if (path.endsWith('/api/academicterms/active')) {
    body = {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true};
  } else if (path.endsWith('/api/userdetails')) {
    // Program Head only: the staff search behind the Faculty page. Role 4 is
    // asked for separately and merged, so answer only the role=3 call.
    body = req.url.queryParameters['role'] == '3'
        ? [
            {'userID': 't1', 'firstname': 'Ben', 'lastname': 'Teach', 'email': 'ben.teach@dbtc-cebu.edu.ph', 'role': 3, 'roleName': 'Teacher', 'programID': 1, 'programCode': 'BSIT'},
            {'userID': 't2', 'firstname': 'Rita', 'lastname': 'Santos', 'email': 'rita.santos@dbtc-cebu.edu.ph', 'role': 3, 'roleName': 'Teacher', 'programID': 1, 'programCode': 'BSIT'},
          ]
        : <Object>[];
  } else if (path.contains('/api/studyloads/class/')) {
    body = [
      for (final n in ['Dela Cruz, Ana', 'Reyes, Mark', 'Santos, Jay', 'Lim, Grace', 'Tan, Rico'])
        {'studyLoadID': 'sl-$n', 'studentUserID': 'u-$n', 'studentName': n, 'subjectCode': 'IT 101', 'subjectTitle': 'Introduction to Computing', 'className': 'BSIT 1A', 'loadStatus': 'Enrolled'},
    ];
  } else if (path.contains('/api/grades/student/')) {
    body = [
      {'gradeID': 'h1', 'studyLoadID': 'sl1', 'subjectCode': 'IT 311', 'subjectTitle': 'Systems Integration and Architecture', 'units': 3, 'termLabel': '2026-2027 (1st Sem)', 'midtermGrade': 1.75, 'finalGrade': 1.5, 'remarksLabel': 'Passed'},
      {'gradeID': 'h2', 'studyLoadID': 'sl2', 'subjectCode': 'IT 312', 'subjectTitle': 'Mobile App Development', 'units': 3, 'termLabel': '2026-2027 (1st Sem)', 'midtermGrade': 2.25},
      {'gradeID': 'h3', 'studyLoadID': 'sl3', 'subjectCode': 'IT 211', 'subjectTitle': 'Data Structures', 'units': 3, 'termLabel': '2025-2026 (2nd Sem)', 'midtermGrade': 2.0, 'finalGrade': 2.25, 'remarksLabel': 'Passed'},
      {'gradeID': 'h4', 'studyLoadID': 'sl4', 'subjectCode': 'GEC 102', 'subjectTitle': 'Understanding the Self', 'units': 3, 'termLabel': '2025-2026 (2nd Sem)', 'midtermGrade': 3.5, 'finalGrade': 4.0, 'remarksLabel': 'Failed'},
    ];
  } else if (path.contains('/api/grades/class/')) {
    body = [
      {'gradeID': 'g1', 'studyLoadID': 'sl1', 'studentName': 'Dela Cruz, Ana', 'midtermGrade': 1.75, 'finalGrade': 1.5},
      {'gradeID': 'g2', 'studyLoadID': 'sl2', 'studentName': 'Reyes, Mark', 'midtermGrade': 2.25, 'finalGrade': 2.0},
      {'gradeID': 'g3', 'studyLoadID': 'sl3', 'studentName': 'Santos, Jay', 'midtermGrade': 3.5, 'finalGrade': 5.0},
      {'gradeID': 'g4', 'studyLoadID': 'sl4', 'studentName': 'Lim, Grace', 'midtermGrade': 4.0},
      {'gradeID': 'g5', 'studyLoadID': 'sl5', 'studentName': 'Tan, Rico', 'midtermGrade': 2.0},
    ];
  } else if (path.endsWith('/api/subjects')) {
    body = [
      {'subjectID': 's1', 'subjectCode': 'IT 101', 'subjectTitle': 'Introduction to Computing', 'lecUnits': 2, 'labUnits': 1, 'lecHours': 2, 'labHours': 3, 'programID': 1, 'yearLevel': 1, 'defaultSemester': 1},
      {'subjectID': 's2', 'subjectCode': 'IT 102', 'subjectTitle': 'Computer Programming 1', 'lecUnits': 3, 'labUnits': 0, 'lecHours': 3, 'labHours': 0, 'programID': 1, 'yearLevel': 1, 'defaultSemester': 1},
    ];
  } else if (path.endsWith('/api/classes')) {
    body = [
      {'classID': 'c1', 'subjectID': 's1', 'subjectCode': 'IT 101', 'subjectTitle': 'Introduction to Computing', 'termID': 't1', 'termSchoolYear': '2026-2027', 'termSemester': 1, 'className': 'BSIT 1A', 'enrolledCount': 38, 'userID': 't1', 'teacherName': 'Ben Teach', 'schedules': [{'scheduleID': 'x', 'classID': 'c1', 'daysOfWeek': 'M/W/F', 'startTime': '08:00:00', 'endTime': '09:00:00', 'room': 'R101'}]},
      {'classID': 'c2', 'subjectID': 's2', 'subjectCode': 'IT 102', 'subjectTitle': 'Computer Programming 1', 'termID': 't1', 'termSchoolYear': '2026-2027', 'termSemester': 1, 'className': 'BSIT 1B', 'enrolledCount': 35, 'userID': 't1', 'teacherName': 'Ben Teach', 'schedules': []},
    ];
  }
  return http.Response(jsonEncode(body), 200);
}

final _boundary = GlobalKey();

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final ro = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('${Platform.environment['OUT'] ?? '/tmp'}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('screens', (tester) async {
    await http.runWithClient(() async {
      await getIt.reset();
      setupLocator();
      getIt.allowReassignment = true;
      getIt.registerSingleton<AuthService>(FakeAuthService());
      tester.view.physicalSize = Size(double.parse(Platform.environment['WIDTH'] ?? '1440'), 900);
      tester.view.devicePixelRatio = 1.0;

      final head = Platform.environment['ROLE'] == '4';
      final auth = AuthenticatedState(
        email: 'ben@dbtc-cebu.edu.ph',
        role: head ? 4 : 3,
        roleName: head ? 'Program Head' : 'Teacher',
        userId: 't1',
        fullName: 'Ben Teach',
      );
      await tester.pumpWidget(RepaintBoundary(key: _boundary, child: buildTeacherApp(auth)));
      await shot(tester, 't01_my_classes');

      final pages = ['Grades', 'Grade Corrections', if (head) 'Program Overview', if (head) 'Faculty'];
      var i = 2;
      for (final p in pages) {
        await tester.tap(find.byKey(ValueKey('nav_$p')));
        await shot(tester, 't0${i++}_${p.replaceAll(' ', '_').toLowerCase()}');
      }

      // The class detail dialog holds the grade summary, so capture it open.
      if (head) {
        await tester.tap(find.byKey(const ValueKey('nav_Program Overview')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('IT 101').first);
        await shot(tester, 't06_class_detail');

        // A roster row opens that student's grade history.
        await tester.tap(find.text('Dela Cruz, Ana').first);
        await shot(tester, 't07_student_grade_history');
      }
    }, () => MockClient(_api));
  });
}
