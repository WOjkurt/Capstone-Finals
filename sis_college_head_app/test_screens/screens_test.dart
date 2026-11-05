// Renders College Head app screens with fake API data and real fonts, saving PNGs for design review.
// Run: OUT=/some/dir flutter test test_screens/screens_test.dart   (WIDTH=1200 for the icons-only menu)
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/blocs/auth_bloc.dart';
import 'package:sis_college_head_app/blocs/faculty_bloc.dart';
import 'package:sis_college_head_app/blocs/students_bloc.dart';
import 'package:sis_college_head_app/repositories/class_repository.dart';
import 'package:sis_college_head_app/repositories/setup_repository.dart';
import 'package:sis_college_head_app/repositories/student_repository.dart';
import 'package:sis_college_head_app/repositories/teacher_repository.dart';
import 'package:sis_college_head_app/theme/app_theme.dart';
import 'package:sis_college_head_app/views/main_layout_view.dart';

import '../test/college_head_shell_test.dart' show TestAuthBloc;
import '../test/test_helpers.dart';

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
  final path = req.url.path;
  Object body = <Object>[];
  if (path.endsWith('/api/AcademicTerms')) {
    body = [
      {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
    ];
  } else if (path.endsWith('/api/AcademicPrograms')) {
    body = [
      {'programID': 1, 'programCode': 'BSIT', 'programName': 'BS Information Technology'},
      {'programID': 2, 'programCode': 'BSME', 'programName': 'BS Mechanical Engineering'},
    ];
  } else if (path.endsWith('/api/Classes')) {
    body = [
      {'classID': 'c1', 'subjectID': 's1', 'subjectCode': 'GEC 101', 'subjectTitle': 'Understanding the Self', 'termID': 't1', 'termSchoolYear': '2026-2027', 'termSemester': 1, 'className': 'BSIT 1A', 'enrolledCount': 38, 'userID': 'u9', 'teacherName': 'Dina Santos', 'isMinor': true, 'schedules': [{'scheduleID': 'x', 'classID': 'c1', 'daysOfWeek': 'M/W/F', 'startTime': '08:00:00', 'endTime': '09:00:00', 'room': 'R101'}]},
      {'classID': 'c2', 'subjectID': 's2', 'subjectCode': 'IT 101', 'subjectTitle': 'Introduction to Computing', 'termID': 't1', 'termSchoolYear': '2026-2027', 'termSemester': 1, 'className': 'BSIT 1A', 'enrolledCount': 36, 'isMinor': false, 'schedules': []},
    ];
  } else if (path.endsWith('/api/students/search')) {
    body = [
      {'userId': 'u1', 'firstname': 'Ana', 'lastname': 'Cruz', 'email': 'ana.cruz@dbtc-cebu.edu.ph', 'role': 5, 'programId': 1, 'programCode': 'BSIT', 'yearLevel': 1, 'lrn': '123456789012'},
      {'userId': 'u2', 'firstname': 'Ben', 'lastname': 'Santos', 'email': 'ben.santos@dbtc-cebu.edu.ph', 'role': 5, 'programId': 2, 'programCode': 'BSME', 'yearLevel': 2},
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
    tester.view.physicalSize = Size(double.parse(Platform.environment['WIDTH'] ?? '1440'), 900);
    tester.view.devicePixelRatio = 1.0;
    final client = MockClient(_api);
    final auth = AuthenticatedState(
      email: 'carla@dbtc-cebu.edu.ph', role: 6, roleName: 'College Head', userId: 'c1', fullName: 'Carla Head');
    final students = StudentsBloc(StudentRepository(MockAuthService(), client), AcademicSetupRepository(MockAuthService(), client));
    final faculty = FacultyBloc(TeacherRepository(MockAuthService(), client), ClassRepository(MockAuthService(), client),
        AcademicSetupRepository(MockAuthService(), client));
    await tester.pumpWidget(RepaintBoundary(
      key: _boundary,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: TestAuthBloc(auth)),
            BlocProvider<StudentsBloc>.value(value: students),
            BlocProvider<FacultyBloc>.value(value: faculty),
          ],
          child: MainLayoutView(auth: auth),
        ),
      ),
    ));
    await shot(tester, 'c01_students');
    await tester.enterText(find.byKey(const ValueKey('student_search_field')), 'a');
    await tester.tap(find.byKey(const ValueKey('student_search_button')));
    await shot(tester, 'c02_students_results');
    await tester.tap(find.byKey(const ValueKey('nav_Faculty')));
    await shot(tester, 'c03_faculty');
  });
}
