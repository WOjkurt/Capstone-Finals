import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_college_head_app/injection.dart';
import 'package:sis_college_head_app/models/grading_models.dart';
import 'package:sis_college_head_app/repositories/class_repository.dart';
import 'package:sis_college_head_app/repositories/setup_repository.dart';
import 'package:sis_college_head_app/views/widgets/study_load_builder_dialog.dart';
import 'test_helpers.dart';

const _student = UserSearchResultModel(
  userId: 'usr-1',
  firstname: 'Ana',
  lastname: 'Cruz',
  email: 'ana.cruz@dbtc-cebu.edu.ph',
  programCode: 'BSIT',
  yearLevel: 2,
  role: 5,
);

Map<String, dynamic> _item({
  required String subjectCode,
  String category = 'regular',
  String? classId = 'cls-1',
  double units = 3.0,
  String matchType = 'auto',
  String prerequisiteStatus = 'met',
  List<String> prerequisiteMessages = const [],
  String standingStatus = 'not_required',
  bool alreadyPassed = false,
  bool alreadyEnrolledThisTerm = false,
  List<Map<String, dynamic>> corequisites = const [],
  List<Map<String, dynamic>> options = const [],
}) =>
    {
      'subjectId': 'subj-$subjectCode',
      'subjectCode': subjectCode,
      'subjectTitle': '$subjectCode title',
      'classId': classId,
      'className': 'BSIT 2-A',
      'matchType': matchType,
      'category': category,
      'subjectYearLevel': 2,
      'units': units,
      'prerequisiteStatus': prerequisiteStatus,
      'prerequisiteMessages': prerequisiteMessages,
      'alreadyPassed': alreadyPassed,
      'alreadyEnrolledThisTerm': alreadyEnrolledThisTerm,
      'standingStatus': standingStatus,
      'corequisites': corequisites,
      'options': options,
    };

/// Fake API for the builder: terms, the proposed block, the unit limit, and
/// whatever enroll-batch returns. Records the bodies it was sent.
class _BuilderApi {
  List<Map<String, dynamic>> items = [];
  double maxUnits = 21;
  double currentUnits = 0;
  bool retakesOutsideLimit = false;

  final List<Map<String, dynamic>> batchBodies = [];
  final List<Map<String, dynamic>> singleBodies = [];

  MockClient get client => MockClient((req) async {
        final path = req.url.path.toLowerCase();

        if (path.endsWith('/api/academicterms')) {
          return http.Response(
              jsonEncode([
                {
                  'termID': 'term-1',
                  'schoolYear': '2026-2027',
                  'semester': 1,
                  'isActive': true,
                }
              ]),
              200);
        }
        if (path.endsWith('/api/studyloads/unit-limit')) {
          return http.Response(
              jsonEncode({
                'maxUnits': maxUnits,
                'currentUnits': currentUnits,
                'retakesOutsideLimit': retakesOutsideLimit,
              }),
              200);
        }
        if (path.endsWith('/api/studyloads/proposed-block')) {
          return http.Response(jsonEncode(items), 200);
        }
        if (path.endsWith('/api/studyloads/enroll-batch')) {
          batchBodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(
              jsonEncode({
                'results': [
                  for (final i in items)
                    {
                      'subjectCode': i['subjectCode'],
                      'classId': i['classId'],
                      'success': true,
                      'studyLoadId': 'sl-${i['subjectCode']}',
                    }
                ],
              }),
              200);
        }
        if (path.endsWith('/api/studyloads/enroll-single')) {
          singleBodies.add(jsonDecode(req.body) as Map<String, dynamic>);
          return http.Response(
              jsonEncode({'success': true, 'studyLoadId': 'sl-forced'}), 200);
        }
        return http.Response('[]', 200);
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _BuilderApi api;

  setUp(() async {
    await getIt.reset();
    api = _BuilderApi();
    getIt.registerSingleton<ClassRepository>(
        ClassRepository(MockAuthService(), api.client));
    getIt.registerSingleton<AcademicSetupRepository>(
        AcademicSetupRepository(MockAuthService(), api.client));
  });

  tearDown(() async => getIt.reset());

  /// Pumps the builder the way the College Head app opens it.
  Future<void> pumpBuilder(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StudyLoadBuilderDialog(
          student: _student,
          initialTermId: 'term-1',
          initialTermLabel: '2026-2027 (1st Sem)',
          isCollegeHead: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  bool isTicked(WidgetTester tester, String subjectCode) {
    final cb = tester.widget<Checkbox>(
      find.byKey(ValueKey('checkbox_$subjectCode')),
    );
    return cb.value ?? false;
  }

  group('what the builder pre-ticks', () {
    testWidgets('regular subjects start ticked', (tester) async {
      api.items = [_item(subjectCode: 'IT211')];
      await pumpBuilder(tester);

      expect(isTicked(tester, 'IT211'), isTrue);
    });

    testWidgets('retakes and back subjects start unticked', (tester) async {
      api.items = [
        _item(subjectCode: 'IT211'),
        _item(subjectCode: 'IT111', category: 'retake'),
        _item(subjectCode: 'MATH102', category: 'back_subject'),
      ];
      await pumpBuilder(tester);

      expect(isTicked(tester, 'IT211'), isTrue);
      expect(isTicked(tester, 'IT111'), isFalse,
          reason: 'a retake is a decision, not a default');
      expect(isTicked(tester, 'MATH102'), isFalse);
    });

    testWidgets('a subject with an unmet prerequisite is not ticked',
        (tester) async {
      api.items = [
        _item(
          subjectCode: 'IT311',
          prerequisiteStatus: 'unmet',
          prerequisiteMessages: ['IT211 not yet passed'],
        ),
      ];
      await pumpBuilder(tester);

      expect(isTicked(tester, 'IT311'), isFalse);
    });

    testWidgets('already passed or already enrolled cannot be ticked',
        (tester) async {
      api.items = [
        _item(subjectCode: 'IT101', alreadyPassed: true),
        _item(subjectCode: 'IT102', alreadyEnrolledThisTerm: true),
      ];
      await pumpBuilder(tester);

      for (final code in ['IT101', 'IT102']) {
        final cb = tester.widget<Checkbox>(
          find.byKey(ValueKey('checkbox_$code')),
        );
        expect(cb.value ?? false, isFalse, reason: code);
        expect(cb.onChanged, isNull, reason: '$code must be disabled');
      }
    });

    testWidgets('a subject with no class offered cannot be ticked',
        (tester) async {
      api.items = [
        _item(
          subjectCode: 'IT250',
          matchType: 'no_class_offered',
          classId: '',
        ),
      ];
      await pumpBuilder(tester);

      final cb = tester.widget<Checkbox>(
        find.byKey(const ValueKey('checkbox_IT250')),
      );
      expect(cb.onChanged, isNull);
    });
  });

  group('what a College Head is allowed to do', () {
    testWidgets('only Save as pending is offered, never Enroll now',
        (tester) async {
      api.items = [_item(subjectCode: 'IT211')];
      await pumpBuilder(tester);

      expect(find.byKey(const ValueKey('save_as_pending_button')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('enroll_now_button')), findsNothing,
          reason: 'only the Registrar may enroll directly');
    });

    testWidgets('saving sends the subjects as pending', (tester) async {
      api.items = [_item(subjectCode: 'IT211')];
      await pumpBuilder(tester);

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();

      expect(api.batchBodies, hasLength(1));
      expect(api.batchBodies.single['asPending'], isTrue);
    });

    testWidgets('a forced subject is still submitted as pending',
        (tester) async {
      api.items = [
        _item(
          subjectCode: 'IT311',
          prerequisiteStatus: 'unmet',
          prerequisiteMessages: ['IT211 not yet passed'],
        ),
      ];
      await pumpBuilder(tester);

      await tester.tap(find.byKey(const ValueKey('force_button_IT311')));
      await tester.pumpAndSettle();

      // The as-pending choice is not offered; it is explained instead.
      expect(find.byKey(const ValueKey('force_as_pending_checkbox')),
          findsNothing);

      await tester.enterText(find.byKey(const ValueKey('force_reason_field')),
          'Dean approved the sequence');
      await tester.tap(find.byKey(const ValueKey('confirm_force_button')));
      await tester.pumpAndSettle();

      expect(api.singleBodies, hasLength(1));
      expect(api.singleBodies.single['asPending'], isTrue);
      expect(api.singleBodies.single['force'], isTrue);
      expect(api.singleBodies.single['forceReason'],
          'Dean approved the sequence');
    });

    testWidgets('a force with no reason is refused before any request',
        (tester) async {
      api.items = [
        _item(
          subjectCode: 'IT311',
          prerequisiteStatus: 'unmet',
          prerequisiteMessages: ['IT211 not yet passed'],
        ),
      ];
      await pumpBuilder(tester);

      await tester.tap(find.byKey(const ValueKey('force_button_IT311')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm_force_button')));
      await tester.pumpAndSettle();

      expect(api.singleBodies, isEmpty,
          reason: 'the reason is what the Registrar reads; it is required');
    });
  });

  group('the unit limit', () {
    testWidgets('staying under the limit saves without asking for a reason',
        (tester) async {
      api.maxUnits = 21;
      api.items = [_item(subjectCode: 'IT211', units: 3)];
      await pumpBuilder(tester);

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('overload_reason_field')), findsNothing);
      expect(api.batchBodies, hasLength(1));
    });

    testWidgets('going over the limit warns and demands a reason',
        (tester) async {
      api.maxUnits = 6;
      api.items = [
        _item(subjectCode: 'IT211', units: 3),
        _item(subjectCode: 'IT212', units: 3),
        _item(subjectCode: 'IT213', units: 3),
      ];
      await pumpBuilder(tester);

      expect(find.byKey(const ValueKey('unit_limit_warning')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('save_as_pending_button')));
      await tester.pumpAndSettle();

      // Nothing is sent until a reason is given.
      expect(find.byKey(const ValueKey('overload_reason_field')),
          findsOneWidget);
      expect(api.batchBodies, isEmpty);

      await tester.enterText(
          find.byKey(const ValueKey('overload_reason_field')),
          'Graduating this year');
      await tester.tap(find.byKey(const ValueKey('confirm_over_limit_button')));
      await tester.pumpAndSettle();

      expect(api.batchBodies, hasLength(1));
      expect(api.batchBodies.single['overloadReason'], 'Graduating this year');
      expect(api.batchBodies.single['asPending'], isTrue);
    });
  });
}
