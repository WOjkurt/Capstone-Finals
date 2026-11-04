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
  final path = req.url.path;
  Object body = <Object>[];
  if (path.endsWith('/api/AcademicTerms')) {
    body = [
      {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true}
    ];
  } else if (path.endsWith('/api/Classes') || path.endsWith('/api/classes')) {
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
    }, () => MockClient(_api));
  });
}
