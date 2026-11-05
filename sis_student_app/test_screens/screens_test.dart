// Renders Student app screens with fake API data and real fonts, saving PNGs for design review.
// Run: OUT=/some/dir WIDTH=360 HEIGHT=780 flutter test test_screens/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_student_app/injection.dart';
import 'package:sis_student_app/services/auth_service.dart';

import '../test/menu_test.dart' show FakeAuthService, buildStudentApp, fakeApi, studentAuth;

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
      final width = double.parse(Platform.environment['WIDTH'] ?? '360');
      tester.view.physicalSize = Size(width, double.parse(Platform.environment['HEIGHT'] ?? '780'));
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(RepaintBoundary(key: _boundary, child: buildStudentApp(studentAuth())));
      final tag = width < 700 ? 'phone' : 'desktop';
      await shot(tester, '${tag}_1_schedule');
      const pages = {'Grades': 'My Grades', 'Clearance': 'Clearance Status', 'Profile': 'Profile'};
      var i = 2;
      for (final e in pages.entries) {
        await tester.tap(width < 700
            ? find.descendant(of: find.byType(NavigationBar), matching: find.text(e.key))
            : find.byKey(ValueKey('nav_${e.value}')));
        await shot(tester, '${tag}_${i++}_${e.key.toLowerCase()}');
      }
    }, () => MockClient(fakeApi));
  });
}
