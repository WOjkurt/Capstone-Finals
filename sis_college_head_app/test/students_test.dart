import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/blocs/students_bloc.dart';
import 'package:sis_college_head_app/injection.dart';
import 'package:sis_college_head_app/models/grading_models.dart';
import 'package:sis_college_head_app/repositories/class_repository.dart';
import 'package:sis_college_head_app/repositories/setup_repository.dart';
import 'package:sis_college_head_app/repositories/student_repository.dart';
import 'package:sis_college_head_app/views/students_view.dart';
import 'package:sis_college_head_app/views/widgets/student_load_dialog.dart';
import 'test_helpers.dart';

const _student = UserSearchResultModel(
  userId: 'usr-1',
  firstname: 'Ada',
  lastname: 'Lovelace',
  email: 'ada@dbtc-cebu.edu.ph',
  programCode: 'BSIT',
  yearLevel: 2,
  role: 5,
  lrn: '123456789012',
);

final _termsJson = [
  {'termID': 'term-old', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false},
  {'termID': 'term-active', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
  {'termID': 'term-next', 'schoolYear': '2026-2027', 'semester': 2, 'isActive': false},
];

final _studentJson = {
  'userID': 'usr-1',
  'firstname': 'Ada',
  'lastname': 'Lovelace',
  'email': 'ada@dbtc-cebu.edu.ph',
  'programCode': 'BSIT',
  'yearLevel': 2,
  'lrn': '123456789012',
  'hasLrn': true,
};

Map<String, dynamic> _load(String code, String status, {bool forced = false}) => {
      'studyLoadId': 'sl-$code',
      'subjectCode': code,
      'subjectTitle': '$code title',
      'className': 'BSIT 2A',
      'teacherName': 'J. Teacher',
      'loadStatus': status,
      'termLabel': '2026-2027 (1st Sem)',
      'isForced': forced,
    };

Map<String, dynamic> _proposedItem() => {
      'subjectId': 'subj-1',
      'subjectCode': 'IT211',
      'subjectTitle': 'Data Structures',
      'classId': 'cls-1',
      'className': 'BSIT 2A',
      'matchType': 'auto',
      'category': 'regular',
      'subjectYearLevel': 2,
      'units': 3.0,
      'prerequisiteStatus': 'met',
      'prerequisiteMessages': <dynamic>[],
      'alreadyPassed': false,
      'alreadyEnrolledThisTerm': false,
      'standingStatus': 'not_required',
      'corequisites': <dynamic>[],
      'options': <dynamic>[],
    };

Future<void> _registerRepos(http.Client client) async {
  await getIt.reset();
  getIt.registerSingleton<ClassRepository>(
      ClassRepository(MockAuthService(), client));
  getIt.registerSingleton<AcademicSetupRepository>(
      AcademicSetupRepository(MockAuthService(), client));
  getIt.registerSingleton<StudentRepository>(
      StudentRepository(MockAuthService(), client));
}

void _setDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
}

void main() {
  group('StudentRepository', () {
    test('searchStudents calls GET /api/students/search with q', () async {
      Uri? captured;
      final client = MockClient((req) async {
        captured = req.url;
        return http.Response(jsonEncode([_studentJson]), 200);
      });

      final results = await StudentRepository(MockAuthService(), client)
          .searchStudents(' 123456789012 ');

      expect(captured!.path, '/api/students/search');
      expect(captured!.queryParameters['q'], '123456789012');
      expect(results.single.fullName, 'Ada Lovelace');
      expect(results.single.lrn, '123456789012');
    });
  });

  group('StudentsBloc', () {
    StudentsBloc buildBloc(http.Client client) => StudentsBloc(
          StudentRepository(MockAuthService(), client),
          AcademicSetupRepository(MockAuthService(), client),
        );

    test('StudentsStarted loads terms newest first and selects the active term', () async {
      final bloc = buildBloc(MockClient((req) async =>
          http.Response(jsonEncode(_termsJson), 200)));
      addTearDown(bloc.close);

      bloc.add(StudentsStarted());
      await bloc.stream.firstWhere((s) => !s.isLoadingTerms);

      expect(bloc.state.terms.map((t) => t.termId),
          ['term-next', 'term-active', 'term-old']);
      expect(bloc.state.selectedTermId, 'term-active');
    });

    test('refreshing keeps the chosen term while it still exists', () async {
      final bloc = buildBloc(MockClient((req) async => http.Response(jsonEncode(_termsJson), 200)));
      addTearDown(bloc.close);
      bloc.add(StudentsStarted());
      await bloc.stream.firstWhere((s) => !s.isLoadingTerms);
      bloc.add(StudentsTermSelected('term-old'));
      await bloc.stream.firstWhere((s) => s.selectedTermId == 'term-old');

      bloc.add(StudentsStarted());
      await bloc.stream.firstWhere((s) => s.isLoadingTerms);
      await bloc.stream.firstWhere((s) => !s.isLoadingTerms);

      expect(bloc.state.selectedTermId, 'term-old');
    });

    test('StudentsStarted selects the newest term when none is active', () async {
      final noActive = _termsJson
          .map((t) => {...t, 'isActive': false})
          .toList();
      final bloc = buildBloc(MockClient((req) async =>
          http.Response(jsonEncode(noActive), 200)));
      addTearDown(bloc.close);

      bloc.add(StudentsStarted());
      await bloc.stream.firstWhere((s) => !s.isLoadingTerms);

      expect(bloc.state.selectedTermId, 'term-next');
    });

    test('empty search does not call the API and clears results', () async {
      var calls = 0;
      final bloc = buildBloc(MockClient((req) async {
        calls++;
        return http.Response('[]', 200);
      }));
      addTearDown(bloc.close);

      bloc.add(StudentsSearchRequested('   '));
      await Future<void>.delayed(Duration.zero);

      expect(calls, 0);
      expect(bloc.state.hasSearched, isFalse);
      expect(bloc.state.results, isEmpty);
    });

    test('search failure shows a message and no results', () async {
      final bloc = buildBloc(MockClient((req) async =>
          http.Response(jsonEncode({'message': 'Access denied.'}), 403)));
      addTearDown(bloc.close);

      bloc.add(StudentsSearchRequested('Ada'));
      await bloc.stream.firstWhere((s) => s.hasSearched);

      expect(bloc.state.results, isEmpty);
      expect(bloc.state.errorMessage, isNotNull);
    });
  });

  group('StudentsView', () {
    testWidgets('searching shows results and Open shows the student load for the selected term',
        (tester) async {
      _setDesktopSize(tester);
      String? loadsTermId;
      final client = MockClient((req) async {
        switch (req.url.path) {
          case '/api/AcademicTerms':
            return http.Response(jsonEncode(_termsJson), 200);
          case '/api/students/search':
            return http.Response(jsonEncode([_studentJson]), 200);
          case '/api/studyloads/student/usr-1':
            loadsTermId = req.url.queryParameters['termId'];
            return http.Response(jsonEncode([_load('IT211', 'Enrolled')]), 200);
        }
        return http.Response('[]', 200);
      });
      await _registerRepos(client);
      final bloc = StudentsBloc(getIt<StudentRepository>(), getIt<AcademicSetupRepository>());
      addTearDown(bloc.close);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BlocProvider<StudentsBloc>.value(
            value: bloc,
            child: const StudentsView(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Type an LRN or name and press Search.'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('student_search_field')), '123456789012');
      await tester.tap(find.byKey(const ValueKey('student_search_button')));
      await tester.pumpAndSettle();

      expect(find.text('Ada Lovelace'), findsOneWidget);

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(loadsTermId, 'term-active');
      expect(find.text('IT211 - IT211 title'), findsOneWidget);
    });
  });

  group('StudentLoadDialog', () {
    Future<void> pumpDialog(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: StudentLoadDialog(
            student: _student,
            termId: 'term-active',
            termLabel: '2026-2027 — 1st Sem',
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('shows loads with statuses and a waiting-for-Registrar notice', (tester) async {
      _setDesktopSize(tester);
      await _registerRepos(MockClient((req) async {
        if (req.url.path == '/api/studyloads/student/usr-1') {
          return http.Response(jsonEncode([
            _load('IT211', 'Enrolled'),
            _load('IT212', 'Pending', forced: true),
            _load('IT213', 'Rejected'),
          ]), 200);
        }
        return http.Response('[]', 200);
      }));

      await pumpDialog(tester);

      expect(find.text('1 subject(s) waiting for Registrar approval.'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.textContaining('Forced'), findsOneWidget);
      // View only: no Registrar actions here.
      expect(find.text('Finalize'), findsNothing);
      expect(find.text('Reject'), findsNothing);
      expect(find.text('Drop'), findsNothing);
    });

    testWidgets('shows a hint when the student has no subjects this term', (tester) async {
      _setDesktopSize(tester);
      await _registerRepos(MockClient((req) async => http.Response('[]', 200)));

      await pumpDialog(tester);

      expect(find.textContaining('No subjects for this term yet.'), findsOneWidget);
    });

    testWidgets('Build study load opens the builder without Enroll now, saves as Pending, then refreshes',
        (tester) async {
      _setDesktopSize(tester);
      bool? capturedAsPending;
      var loadFetches = 0;
      await _registerRepos(MockClient((req) async {
        switch (req.url.path) {
          case '/api/studyloads/student/usr-1':
            loadFetches++;
            return http.Response(
                jsonEncode(capturedAsPending == null
                    ? []
                    : [_load('IT211', 'Pending')]),
                200);
          case '/api/AcademicTerms':
            return http.Response(jsonEncode(_termsJson), 200);
          case '/api/studyloads/proposed-block':
            return http.Response(jsonEncode([_proposedItem()]), 200);
          case '/api/studyloads/enroll-batch':
            capturedAsPending =
                (jsonDecode(req.body) as Map<String, dynamic>)['asPending'] as bool?;
            return http.Response(jsonEncode([
              {'classId': 'cls-1', 'enrolled': true, 'studyLoadId': 'sl-1', 'reasons': []}
            ]), 200);
        }
        return http.Response('[]', 200);
      }));

      await pumpDialog(tester);
      expect(loadFetches, 1);

      await tester.tap(find.byKey(const ValueKey('build_study_load_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('save_as_pending_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('enroll_now_button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();

      expect(capturedAsPending, isTrue);
      expect(loadFetches, 2);
      expect(find.text('1 subject(s) waiting for Registrar approval.'), findsOneWidget);
    });
  });
}
