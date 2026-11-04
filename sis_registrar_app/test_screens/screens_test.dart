// Renders Registrar app screens with fake API data and real fonts, saving PNGs for design review.
// Run: OUT=/some/dir flutter test test_screens/screens_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_registrar_app/blocs/applications_bloc.dart';
import 'package:sis_registrar_app/blocs/auth_bloc.dart';
import 'package:sis_registrar_app/blocs/clearance_bloc.dart';
import 'package:sis_registrar_app/blocs/corrections_bloc.dart';
import 'package:sis_registrar_app/blocs/dashboard_bloc.dart';
import 'package:sis_registrar_app/blocs/link_accounts_bloc.dart';
import 'package:sis_registrar_app/blocs/responses_bloc.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/blocs/staff_bloc.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/services/auth_service.dart';
import 'package:sis_registrar_app/theme/app_theme.dart';
import 'package:sis_registrar_app/views/clearance_view.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';

import 'fake_api.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async =>
      {'Authorization': 'Bearer t', 'Content-Type': 'application/json'};
  @override
  Future<String?> getToken() async => 't';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _loadFonts() async {
  final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/homebrew/share/flutter';
  final dir = '$sdk/bin/cache/artifacts/material_fonts';
  ByteData read(String f) => ByteData.view(File('$dir/$f').readAsBytesSync().buffer);
  // FlutterTest is the test runner's default family; mapping it to Roboto mirrors the browser's fallback.
  final inter = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(Future.value(ByteData.view(File('assets/fonts/Inter-$f.ttf').readAsBytesSync().buffer)));
  }
  await inter.load();
  for (final family in ['Roboto', 'FlutterTest', 'monospace']) {
    final loader = FontLoader(family);
    for (final f in ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf']) {
      loader.addFont(Future.value(read(f)));
    }
    await loader.load();
  }
  await (FontLoader('MaterialIcons')..addFont(Future.value(read('MaterialIcons-Regular.otf')))).load();
}

final _boundary = GlobalKey();

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final out = Platform.environment['OUT'] ?? '/tmp';
  await tester.runAsync(() async {
    final ro = _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await ro.toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget app() => MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc(getIt<AuthService>())),
        BlocProvider<DashboardBloc>(create: (_) => getIt<DashboardBloc>()),
        BlocProvider<ResponsesBloc>(create: (_) => getIt<ResponsesBloc>()),
        BlocProvider<ApplicationsBloc>(create: (_) => getIt<ApplicationsBloc>()),
        BlocProvider<LinkAccountsBloc>(create: (_) => getIt<LinkAccountsBloc>()),
        BlocProvider<ClearanceBloc>(create: (_) => getIt<ClearanceBloc>()),
        BlocProvider<SetupBloc>(create: (_) => getIt<SetupBloc>()),
        BlocProvider<CorrectionsBloc>(create: (_) => getIt<CorrectionsBloc>()),
        BlocProvider<StaffBloc>(create: (_) => getIt<StaffBloc>()),
      ],
      child: RepaintBoundary(
        key: _boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: MainLayoutView(
            auth: AuthenticatedState(email: 'registrar@dbtc-cebu.edu.ph', role: 2, roleName: 'Registrar', userId: 'reg-1', fullName: 'Rita Reg'),
          ),
        ),
      ),
    );

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
      await tester.pumpWidget(app());
      await shot(tester, '01_dashboard');

      if (Platform.environment['STUDENT'] == '1') {
        await tester.tap(find.byKey(const ValueKey('nav_Students')));
        await tester.pumpAndSettle();
        await tester.enterText(find.descendant(of: find.byType(ClearanceView), matching: find.byType(TextField)).first, 'a');
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        await shot(tester, '19_student_search');
        await tester.tap(find.text('Ana Cruz').first);
        await shot(tester, '20_student_study_load');
        for (final tab in ['Grades', 'Credits', 'Grade release', 'History']) {
          await tester.tap(find.descendant(of: find.byKey(const ValueKey('student_tabs')), matching: find.text(tab)));
          await shot(tester, '2${['Grades', 'Credits', 'Grade release', 'History'].indexOf(tab) + 1}_student_${tab.replaceAll(' ', '_').toLowerCase()}');
        }
        return;
      }

      final pages = Platform.environment['PAGES']?.split(',') ??
          ['Admissions', 'Students', 'Pending loads', 'Grade corrections', 'Reports', 'Setup'];
      var i = 2;
      for (final p in pages) {
        await tester.tap(find.byKey(ValueKey('nav_$p')));
        await shot(tester, '${(i++).toString().padLeft(2, '0')}_${p.replaceAll(' ', '_').toLowerCase()}');
      }
    }, () => MockClient(fakeApi));
  });
}
