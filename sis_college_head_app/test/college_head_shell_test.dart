import 'package:flutter/material.dart';
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
import 'package:sis_college_head_app/views/main_layout_view.dart';
import 'test_helpers.dart';

class TestAuthBloc extends Bloc<AuthEvent, AuthState> implements AuthBloc {
  final List<AuthEvent> recordedEvents = [];
  TestAuthBloc(super.initialState) {
    on<AuthEvent>((event, emit) {
      recordedEvents.add(event);
    });
  }
}

void main() {
  group('Role gate', () {
    test('allows Admin (1) and College Head (6)', () {
      expect(isAllowedRole(1), isTrue);
      expect(isAllowedRole(6), isTrue);
    });

    test('rejects Registrar, Teacher, Program Head, Student and unknown roles', () {
      for (final role in [0, 2, 3, 4, 5, 7]) {
        expect(isAllowedRole(role), isFalse, reason: 'role $role');
      }
    });
  });

  group('MainLayoutView', () {
    late TestAuthBloc authBloc;
    late StudentsBloc studentsBloc;
    late FacultyBloc facultyBloc;

    setUp(() {
      final client = MockClient((req) async => http.Response('[]', 200));
      studentsBloc = StudentsBloc(
        StudentRepository(MockAuthService(), client),
        AcademicSetupRepository(MockAuthService(), client),
      );
      facultyBloc = FacultyBloc(
        TeacherRepository(MockAuthService(), client),
        ClassRepository(MockAuthService(), client),
        AcademicSetupRepository(MockAuthService(), client),
      );
      authBloc = TestAuthBloc(
        AuthenticatedState(
          email: 'test.collegehead@dbtc-cebu.edu.ph',
          role: 6,
          roleName: 'College Head',
          userId: 'test-uid-6',
          fullName: 'Carla Head',
        ),
      );
    });

    tearDown(() {
      authBloc.close();
      studentsBloc.close();
      facultyBloc.close();
    });

    Widget buildSubject() {
      return MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<StudentsBloc>.value(value: studentsBloc),
            BlocProvider<FacultyBloc>.value(value: facultyBloc),
          ],
          child: MainLayoutView(auth: authBloc.state as AuthenticatedState),
        ),
      );
    }

    void setDesktopSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    testWidgets('shows only the Students and Faculty tabs', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(MainLayoutView.buildNavItems().map((i) => i['title']),
          ['Students', 'Faculty']);
      expect(find.text('College Head'), findsWidgets);
      expect(find.text('Pending loads'), findsNothing);
      expect(find.text('Setup'), findsNothing);
    });

    testWidgets('the menu shows who is signed in, and only icons on a laptop-size screen', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('full_sidebar')), findsOneWidget);
      expect(find.text('Carla Head'), findsOneWidget);
      expect(find.byKey(const ValueKey('change_password_button')), findsOneWidget);

      tester.view.physicalSize = const Size(1200, 800);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('compact_sidebar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav_Faculty')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('page_refresh_button')), findsOneWidget);
    });

    test('the menu name falls back to the email', () {
      expect(AuthenticatedState(email: 'a@x.com', role: 6, roleName: 'College Head', userId: 'u').displayName, 'a@x.com');
    });

    testWidgets('switching to Faculty shows the faculty page', (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Faculty').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Assign teachers to minor subjects, and to majors as a backup, across all programs.'),
        findsOneWidget,
      );
    });

    testWidgets('Log out confirmation mentions the College Head portal and dispatches LogoutRequested',
        (tester) async {
      setDesktopSize(tester);
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sign_out_button')));
      await tester.pumpAndSettle();
      expect(
        find.text("You'll need to sign in again to access the College Head portal."),
        findsOneWidget,
      );

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(authBloc.recordedEvents.whereType<LogoutRequested>(), hasLength(1));
    });
  });
}
