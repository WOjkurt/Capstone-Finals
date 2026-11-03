import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/blocs/faculty_bloc.dart';
import 'package:sis_college_head_app/injection.dart';
import 'package:sis_college_head_app/models/class_models.dart';
import 'package:sis_college_head_app/repositories/class_repository.dart';
import 'package:sis_college_head_app/repositories/setup_repository.dart';
import 'package:sis_college_head_app/repositories/teacher_repository.dart';
import 'package:sis_college_head_app/views/faculty_view.dart';
import 'package:sis_college_head_app/views/widgets/assign_teacher_dialog.dart';
import 'test_helpers.dart';

final _termsJson = [
  {'termID': 'term-active', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
  {'termID': 'term-next', 'schoolYear': '2026-2027', 'semester': 2, 'isActive': false},
];

final _programsJson = [
  {'programID': 1, 'programCode': 'BSIT', 'programName': 'Information Technology'},
  {'programID': 2, 'programCode': 'BSME', 'programName': 'Mechanical Engineering'},
];

Map<String, dynamic> _teacher(String id, String first, String last, int? programId) => {
      'userID': id,
      'firstname': first,
      'lastname': last,
      'email': '$first@dbtc-cebu.edu.ph'.toLowerCase(),
      'programID': programId,
      'role': 3,
    };

final _teachersJson = [
  _teacher('t-it', 'Ian', 'Itteacher', 1),
  _teacher('t-me', 'Mae', 'Meteacher', 2),
  _teacher('t-be', 'Ben', 'Basiced', null),
];

Map<String, dynamic> _class(String id, String code, int programId,
        {bool isMinor = false, String? teacherId, String? teacherName}) =>
    {
      'classID': id,
      'subjectID': 'subj-$id',
      'subjectCode': code,
      'subjectTitle': '$code title',
      'userID': teacherId,
      'teacherName': teacherName,
      'termID': 'term-active',
      'className': programId == 1 ? 'BSIT 1A' : 'BSME 1A',
      'isMinor': isMinor,
      'programID': programId,
      'schedules': <dynamic>[],
    };

List<Map<String, dynamic>> _classesJson() => [
      _class('c1', 'IT 101A', 1),
      _class('c2', 'THEO 101A', 1, isMinor: true),
      _class('c3', 'GEC 101A', 2, isMinor: true, teacherId: 't-be', teacherName: 'Ben Basiced'),
      _class('c4', 'ME 101A', 2, teacherId: 't-me', teacherName: 'Mae Meteacher'),
    ];

/// Fake API for the Faculty tab. [onPatch] sees each PATCH body.
MockClient _api({
  List<Map<String, dynamic>> Function()? classes,
  http.Response Function(http.Request req)? onPatch,
  void Function(Uri url)? onClassesGet,
}) {
  return MockClient((req) async {
    final path = req.url.path;
    if (path == '/api/AcademicTerms') return http.Response(jsonEncode(_termsJson), 200);
    if (path == '/api/AcademicPrograms') return http.Response(jsonEncode(_programsJson), 200);
    if (path == '/api/UserDetails') return http.Response(jsonEncode(_teachersJson), 200);
    if (path == '/api/Classes' && req.method == 'GET') {
      onClassesGet?.call(req.url);
      return http.Response(jsonEncode((classes ?? _classesJson)()), 200);
    }
    if (req.method == 'PATCH' && onPatch != null) return onPatch(req);
    return http.Response('[]', 200);
  });
}

FacultyBloc _bloc(http.Client client) => FacultyBloc(
      TeacherRepository(MockAuthService(), client),
      ClassRepository(MockAuthService(), client),
      AcademicSetupRepository(MockAuthService(), client),
    );

Future<void> _started(FacultyBloc bloc) async {
  bloc.add(FacultyStarted());
  await bloc.stream.firstWhere((s) => !s.isLoading && s.terms.isNotEmpty);
}

void main() {
  group('Repositories', () {
    test('searchTeachers with no query asks for all teachers (role 3)', () async {
      Uri? captured;
      final client = MockClient((req) async {
        captured = req.url;
        return http.Response(jsonEncode(_teachersJson), 200);
      });

      final list = await TeacherRepository(MockAuthService(), client).searchTeachers('');

      expect(captured!.path, '/api/UserDetails');
      expect(captured!.queryParameters, {'role': '3'});
      expect(list.map((t) => t.userId), ['t-it', 't-me', 't-be']);
      expect(list.last.programId, isNull);
    });

    test('assignTeacher sends PATCH /api/classes/{id}/teacher with userID', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      });

      await ClassRepository(MockAuthService(), client).assignTeacher('c2', 't-be');

      expect(captured!.method, 'PATCH');
      expect(captured!.url.path, '/api/classes/c2/teacher');
      expect(jsonDecode(captured!.body), {'userID': 't-be'});
    });

    test('ClassModel parses isMinor and programId', () {
      final c = ClassModel.fromJson(_class('c2', 'THEO 101A', 1, isMinor: true));
      expect(c.isMinor, isTrue);
      expect(c.programId, 1);
      expect(ClassModel.fromJson({'classID': 'x', 'subjectID': 'y', 'termID': 'z', 'className': 'n'}).isMinor, isFalse);
    });
  });

  group('FacultyBloc', () {
    test('starts on the active term and loads its classes', () async {
      Uri? classesUrl;
      final bloc = _bloc(_api(onClassesGet: (u) => classesUrl = u));
      addTearDown(bloc.close);

      await _started(bloc);

      expect(bloc.state.selectedTermId, 'term-active');
      expect(classesUrl!.queryParameters['termId'], 'term-active');
      expect(bloc.state.programs.length, 2);
      expect(bloc.state.teachers.length, 3);
    });

    test('unassigned classes list minor subjects first', () async {
      final bloc = _bloc(_api());
      addTearDown(bloc.close);

      await _started(bloc);

      expect(bloc.state.unassignedClasses.map((c) => c.subjectCode),
          ['THEO 101A', 'IT 101A']);
    });

    test('program filter keeps that program\'s teachers plus anyone teaching in it', () async {
      final bloc = _bloc(_api());
      addTearDown(bloc.close);
      await _started(bloc);

      bloc.add(FacultyProgramSelected(2));
      await bloc.stream.firstWhere((s) => s.selectedProgramId == 2);

      expect(bloc.state.unassignedClasses, isEmpty);
      // Mae is a BSME teacher; Ben (no program) teaches GEC 101A in BSME.
      expect(bloc.state.faculty.map((f) => f.teacher.userId).toSet(), {'t-me', 't-be'});
      final ben = bloc.state.faculty.firstWhere((f) => f.teacher.userId == 't-be');
      expect(ben.classes.single.subjectCode, 'GEC 101A');
      expect(bloc.state.programCodeFor(null), 'No program');

      bloc.add(FacultyProgramSelected(null));
      await bloc.stream.firstWhere((s) => s.selectedProgramId == null);
      expect(bloc.state.faculty.length, 3);
    });

    test('assigning reloads the classes and shows a success message', () async {
      var assigned = false;
      final bloc = _bloc(_api(
        classes: () => assigned
            ? [_class('c2', 'THEO 101A', 1, isMinor: true, teacherId: 't-be', teacherName: 'Ben Basiced')]
            : [_class('c2', 'THEO 101A', 1, isMinor: true)],
        onPatch: (req) {
          assigned = true;
          return http.Response('{}', 200);
        },
      ));
      addTearDown(bloc.close);
      await _started(bloc);
      expect(bloc.state.unassignedClasses.length, 1);

      bloc.add(FacultyAssignRequested(classId: 'c2', teacherUserId: 't-be'));
      await bloc.stream.firstWhere((s) => s.successMessage != null);

      expect(bloc.state.unassignedClasses, isEmpty);
      expect(bloc.state.successMessage, 'Teacher assigned.');
    });

    test('a refused assignment shows the server message', () async {
      final bloc = _bloc(_api(
        onPatch: (req) => http.Response(
            jsonEncode({'message': 'Assigned user must have the Teacher role.'}), 400),
      ));
      addTearDown(bloc.close);
      await _started(bloc);

      bloc.add(FacultyAssignRequested(classId: 'c2', teacherUserId: 'x'));
      await bloc.stream.firstWhere((s) => s.errorMessage != null);

      expect(bloc.state.errorMessage, contains('Teacher role'));
      expect(bloc.state.isAssigning, isFalse);
    });
  });

  group('FacultyView', () {
    testWidgets('shows minor badges and assigns a no-program teacher to a minor class',
        (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      Map<String, dynamic>? patchBody;
      String? patchPath;
      final client = _api(onPatch: (req) {
        patchPath = req.url.path;
        patchBody = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response('{}', 200);
      });
      await getIt.reset();
      getIt.registerSingleton<TeacherRepository>(TeacherRepository(MockAuthService(), client));
      final bloc = _bloc(client);
      addTearDown(bloc.close);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BlocProvider<FacultyBloc>.value(value: bloc, child: const FacultyView()),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Classes without a teacher (2)'), findsOneWidget);
      expect(find.text('Teachers (3)'), findsOneWidget);
      expect(find.text('Minor'), findsOneWidget);

      // THEO 101A is listed first because it is minor.
      await tester.tap(find.text('Assign teacher').first);
      await tester.pumpAndSettle();
      final dialog = find.byType(AssignTeacherDialog);
      await tester.tap(find.descendant(of: dialog, matching: find.text('Ben Basiced')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: dialog, matching: find.text('Assign')));
      await tester.pumpAndSettle();

      expect(patchPath, '/api/classes/c2/teacher');
      expect(patchBody, {'userID': 't-be'});
      expect(find.text('Teacher assigned.'), findsOneWidget);
    });
  });
}
