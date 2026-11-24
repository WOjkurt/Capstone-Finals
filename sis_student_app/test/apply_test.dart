import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_student_app/models/public_enrollment_models.dart';
import 'package:sis_student_app/repositories/public_enrollment_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_student_app/blocs/auth_bloc.dart';
import 'package:sis_student_app/services/auth_service.dart';
import 'package:sis_student_app/theme/app_theme.dart';
import 'package:sis_student_app/views/apply_view.dart';
import 'package:sis_student_app/views/login_view.dart';

Map<String, dynamic> openStatus() => {
      'isOpen': true,
      'termLabel': '2026-2027 (2nd Sem)',
      'closesOn': '2026-11-28',
      'programs': [
        {'programId': 1, 'programCode': 'BSIT', 'programName': 'BS Information Technology'},
        {'programId': 2, 'programCode': 'BSCS', 'programName': 'BS Computer Science'},
      ],
    };

Map<String, dynamic> receipt() => {
      'responseId': '3f2a9c14-0000-4000-8000-000000000001',
      'reference': '3F2A9C14',
      'termLabel': '2026-2027 (2nd Sem)',
      'submittedAt': '2026-11-24T02:00:00Z',
    };

/// The sign-in page builds its button from the auth bloc; applying never touches it.
class FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget signInPage({VoidCallback? onApply}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<AuthBloc>(
        create: (_) => AuthBloc(FakeAuthService()),
        child: LoginView(onApply: onApply),
      ),
    );

void main() {
  group('reading what the server says', () {
    test('a closed status carries no term and no courses', () {
      final status = PublicEnrollmentStatus.fromJson({'isOpen': false});

      expect(status.isOpen, false);
      expect(status.termLabel, isNull);
      expect(status.closesOn, isNull);
      expect(status.programs, isEmpty);
    });

    test('an open status carries the term, the closing day and the courses', () {
      final status = PublicEnrollmentStatus.fromJson(openStatus());

      expect(status.isOpen, true);
      expect(status.termLabel, '2026-2027 (2nd Sem)');
      expect(status.closesOn, DateTime(2026, 11, 28));
      expect(status.programs.map((p) => p.programCode), ['BSIT', 'BSCS']);
      expect(status.programs.first.label, 'BSIT — BS Information Technology');
    });

    test('a receipt keeps the reference the applicant is told to write down', () {
      expect(PublicEnrollmentReceipt.fromJson(receipt()).reference, '3F2A9C14');
    });
  });

  group('the application page', () {
    late List<http.Request> requests;
    late List<String> bodies;
    late Map<String, dynamic> status;
    late int submitStatusCode;
    late Map<String, dynamic> submitBody;
    var backToSignIn = 0;

    http.Client client() => MockClient((req) async {
          requests.add(req);
          bodies.add(req.body);
          if (req.method == 'POST') {
            return http.Response(jsonEncode(submitBody), submitStatusCode);
          }
          return http.Response(jsonEncode(status), 200);
        });

    setUp(() {
      requests = [];
      bodies = [];
      status = openStatus();
      submitStatusCode = 200;
      submitBody = receipt();
      backToSignIn = 0;
    });

    Future<void> pump(WidgetTester tester, {double width = 1280}) async {
      tester.view.physicalSize = Size(width, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await http.runWithClient(() async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: ApplyView(
            repository: PublicEnrollmentRepository(),
            onBackToSignIn: () => backToSignIn++,
          ),
        ));
        await tester.pumpAndSettle();
      }, client);
    }

    Future<void> act(WidgetTester tester, Future<void> Function() action) async {
      await http.runWithClient(() async {
        await action();
        await tester.pumpAndSettle();
      }, client);
    }

    Future<void> type(WidgetTester tester, String key, String value) async {
      await tester.enterText(find.byKey(ValueKey(key)), value);
      await tester.pump();
    }

    /// Opens the calendar on a date field and accepts whatever it opens on, which is fixed:
    /// a birthday opens 18 years ago, anything else opens at the start of this year.
    Future<void> pickDate(WidgetTester tester, String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
    }

    String openedOn({required bool birthday}) {
      final year = DateTime.now().year - (birthday ? 18 : 0);
      return '$year-01-01';
    }

    Future<void> choose(WidgetTester tester, String key, String value) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(value).last, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    /// Everything the form insists on, and nothing more.
    Future<void> fillTheRequiredAnswers(WidgetTester tester) async {
      await type(tester, 'apply_email', 'applicant@example.com');
      await choose(tester, 'apply_course_picker', 'BSIT — BS Information Technology');
      await choose(tester, 'apply:civilStatus', 'Single');
      await type(tester, 'apply:nationality', 'Filipino');
      await type(tester, 'apply:mobileNumber', '09171234567');
      await type(tester, 'apply:barangay', 'Pardo');
      await type(tester, 'apply:cityMunicipality', 'Cebu City');
      await type(tester, 'apply:province', 'Cebu');
      await type(tester, 'apply:zipCode', '6000');
      await type(tester, 'apply:lastSchoolAttended', 'Abellana NHS');
      await pickDate(tester, 'apply:dateOfBirth');
      await pickDate(tester, 'apply:yearGraduated');
    }

    Map<String, dynamic> sentForm() {
      final post = requests.singleWhere((r) => r.method == 'POST');
      final index = requests.indexOf(post);
      return jsonDecode(bodies[index]) as Map<String, dynamic>;
    }

    testWidgets('asks the server whether anyone may apply, without signing in', (tester) async {
      await pump(tester);

      final asked = requests.single;
      expect(asked.method, 'GET');
      expect(asked.url.path, endsWith('/api/public/enrollment/status'));
      // An applicant has no account, so there is nothing to send and nothing must be sent.
      expect(asked.headers.keys.map((k) => k.toLowerCase()), isNot(contains('authorization')));
    });

    testWidgets('says so plainly when enrollment is closed, and offers no form', (tester) async {
      status = {'isOpen': false};

      await pump(tester);

      expect(find.byKey(const ValueKey('apply_closed')), findsOneWidget);
      expect(find.byKey(const ValueKey('apply_submit_button')), findsNothing);
      expect(find.byKey(const ValueKey('apply_open_banner')), findsNothing);
    });

    testWidgets('shows the term and the closing day when enrollment is open', (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('apply_open_banner')), findsOneWidget);
      expect(find.textContaining('2026-2027 (2nd Sem)'), findsWidgets);
      expect(find.textContaining('Nov 28, 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('apply_submit_button')), findsOneWidget);
    });

    testWidgets('a transferee is asked where they are coming from; a new student is not',
        (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('apply:previousCollege')), findsNothing);

      await tester.tap(find.text('Transferring in'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('apply:previousCollege')), findsOneWidget);
      expect(find.byKey(const ValueKey('apply:previousCourse')), findsOneWidget);
      expect(find.byKey(const ValueKey('apply:previousStudentID')), findsOneWidget);
    });

    testWidgets('an address the server would refuse is marked here instead', (tester) async {
      await pump(tester);

      // The page used to accept these and let the server do the refusing, which meant filling in
      // the whole form first and being turned away at the end.
      for (final bad in ['applicant@example', 'appl icant@example.com', 'applicant@', '@example.com']) {
        await type(tester, 'apply_email', bad);
        await act(tester, () async {
          await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
        });
        expect(requests.where((r) => r.method == 'POST'), isEmpty, reason: 'sent "$bad"');
      }

      expect(find.text('That does not look like an email address'), findsWidgets);
    });

    testWidgets('an incomplete form is not sent', (tester) async {
      await pump(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      expect(requests.where((r) => r.method == 'POST'), isEmpty);
      expect(find.textContaining('still need fixing'), findsOneWidget);
    });

    testWidgets('a completed form is sent with the course and the kind of applicant',
        (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final sent = sentForm();
      expect(sent['emailAddress'], 'applicant@example.com');
      final form = sent['form'] as Map<String, dynamic>;
      expect(form['incomingCourse'], 'BSIT');
      expect(form['studentType'], 1);
      expect(form['nationality'], 'Filipino');
      expect(form['mobileNumber'], '09171234567');
      // An old second name for the city would undo the answer above it.
      expect(form.containsKey('cityOfMunicipality'), false);
    });

    testWidgets('a transferee is sent as one', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Transferring in'));
      await tester.pumpAndSettle();
      await fillTheRequiredAnswers(tester);
      await type(tester, 'apply:previousCollege', 'Some University');
      await type(tester, 'apply:previousCourse', 'BS Information Technology');

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final form = sentForm()['form'] as Map<String, dynamic>;
      expect(form['studentType'], 3);
      expect(form['previousCollege'], 'Some University');
    });

    testWidgets('a contact left blank is not sent; one filled in carries its relation',
        (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);
      await type(tester, 'apply_c2:firstName', 'Maria');
      await type(tester, 'apply_c2:lastName', 'Cruz');
      await type(tester, 'apply_c2:contactNo', '09170000002');

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final contacts = sentForm()['contacts'] as List<dynamic>;
      final only = contacts.single as Map<String, dynamic>;
      expect(only['relationType'], 2);
      expect(only['firstName'], 'Maria');
    });

    testWidgets('the medical checklists are asked for, and sent as lists', (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);

      await tester.tap(find.byKey(const ValueKey('apply_presentMedicalConditions:Allergies')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('apply_presentMedicalConditions:Lung Problems')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('apply_immunizationHistory:BCG')));
      await tester.pump();

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final form = sentForm()['form'] as Map<String, dynamic>;
      expect(form['presentMedicalConditions'], ['Allergies', 'Lung Problems']);
      expect(form['immunizationHistory'], ['BCG']);
      // Nothing ticked means the key is absent, not an empty list.
      expect(form['pastMedicalHistory'], isNull);
    });

    testWidgets('a ticked box can be unticked back to nothing', (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);

      final chip = find.byKey(const ValueKey('apply_pastMedicalHistory:Fractures'));
      await tester.tap(chip);
      await tester.pump();
      await tester.tap(chip);
      await tester.pump();

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      expect((sentForm()['form'] as Map<String, dynamic>)['pastMedicalHistory'], isNull);
    });

    testWidgets('a transferee previous student number is sent under the key the system uses',
        (tester) async {
      await pump(tester);
      await tester.tap(find.text('Transferring in'));
      await tester.pumpAndSettle();
      await fillTheRequiredAnswers(tester);
      await type(tester, 'apply:previousCollege', 'Some University');
      await type(tester, 'apply:previousCourse', 'BSIT');
      await type(tester, 'apply:previousStudentID', '2019-00123');

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final form = sentForm()['form'] as Map<String, dynamic>;
      expect(form['previousStudentID'], '2019-00123');
      expect(form.containsKey('previousStudentId'), false);
    });

    testWidgets('a parent is asked the things the Google Form asked a parent', (tester) async {
      await pump(tester);

      // Father and mother: birthday, workplace and Messenger account.
      for (final prefix in ['apply_c1', 'apply_c2']) {
        expect(find.byKey(ValueKey('$prefix:dateOfBirth')), findsOneWidget);
        expect(find.byKey(ValueKey('$prefix:workplace')), findsOneWidget);
        expect(find.byKey(ValueKey('$prefix:facebookAccount')), findsOneWidget);
        expect(find.byKey(ValueKey('$prefix:guardianRelationshipDescription')), findsNothing);
      }
    });

    testWidgets('a guardian is asked how they are related and whether the student lives with them',
        (tester) async {
      await pump(tester);

      expect(find.byKey(const ValueKey('apply_c3:guardianRelationshipDescription')), findsOneWidget);
      expect(find.byKey(const ValueKey('apply_lives_with_guardian')), findsOneWidget);
      // Not asked of a guardian on the Google Form, so not asked here either.
      expect(find.byKey(const ValueKey('apply_c3:dateOfBirth')), findsNothing);
      expect(find.byKey(const ValueKey('apply_c3:workplace')), findsNothing);
      expect(find.byKey(const ValueKey('apply_c3:facebookAccount')), findsNothing);
    });

    testWidgets('a parent is sent with every detail that was filled in', (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);
      await type(tester, 'apply_c1:firstName', 'Pedro');
      await type(tester, 'apply_c1:lastName', 'Cruz');
      await type(tester, 'apply_c1:contactNo', '09170000001');
      await pickDate(tester, 'apply_c1:dateOfBirth');
      await type(tester, 'apply_c1:workplace', 'City Hall');
      await type(tester, 'apply_c1:facebookAccount', 'pedro.cruz');

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final father = (sentForm()['contacts'] as List<dynamic>).single as Map<String, dynamic>;
      expect(father['relationType'], 1);
      expect(father['dateOfBirth'], openedOn(birthday: true));
      expect(father['workplace'], 'City Hall');
      expect(father['facebookAccount'], 'pedro.cruz');
    });

    testWidgets('the guardian box is sent with the guardian, and never on its own', (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);

      // Ticked with no guardian named: there is nobody for it to describe, so nothing is sent.
      await tester.tap(find.byKey(const ValueKey('apply_lives_with_guardian')));
      await tester.pump();

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      expect(sentForm()['contacts'], isEmpty);
    });

    testWidgets('a named guardian carries the box and the relationship', (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);
      await type(tester, 'apply_c3:firstName', 'Tita');
      await type(tester, 'apply_c3:lastName', 'Reyes');
      await type(tester, 'apply_c3:guardianRelationshipDescription', 'Aunt');
      await tester.tap(find.byKey(const ValueKey('apply_lives_with_guardian')));
      await tester.pump();

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final guardian = (sentForm()['contacts'] as List<dynamic>).single as Map<String, dynamic>;
      expect(guardian['relationType'], 3);
      expect(guardian['guardianRelationshipDescription'], 'Aunt');
      expect(guardian['livingWithGuardian'], true);
    });

    testWidgets('only a transferee is asked which year level they are entering', (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('apply_year_level_picker')), findsNothing);

      await tester.tap(find.text('Transferring in'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('apply_year_level_picker')), findsOneWidget);

      await fillTheRequiredAnswers(tester);
      await type(tester, 'apply:previousCollege', 'Some University');
      await type(tester, 'apply:previousCourse', 'BSIT');
      await choose(tester, 'apply_year_level_picker', '3rd year');

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      expect((sentForm()['form'] as Map<String, dynamic>)['yearLevel'], 3);
    });

    testWidgets('the reference is shown afterwards, and says no email is coming', (tester) async {
      await pump(tester);
      await fillTheRequiredAnswers(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      expect(find.byKey(const ValueKey('apply_submitted')), findsOneWidget);
      expect(find.byKey(const ValueKey('apply_reference')), findsOneWidget);
      expect(find.text('3F2A9C14'), findsOneWidget);
      expect(find.textContaining('do not send a confirmation email'), findsOneWidget);
      // The form is gone, so a second tap cannot send it twice.
      expect(find.byKey(const ValueKey('apply_submit_button')), findsNothing);
    });

    testWidgets('a refusal is reported and the answers are kept', (tester) async {
      submitStatusCode = 400;
      submitBody = {'message': 'Online enrollment is closed right now.'};

      await pump(tester);
      await fillTheRequiredAnswers(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      expect(find.textContaining('closed right now'), findsOneWidget);
      expect(find.byKey(const ValueKey('apply_submitted')), findsNothing);
      // Still on the form, with what was typed still in it.
      expect(find.byKey(const ValueKey('apply_submit_button')), findsOneWidget);
      expect(find.text('Filipino'), findsOneWidget);
    });

    testWidgets('too many tries is explained rather than reported as a failure', (tester) async {
      submitStatusCode = 429;
      submitBody = {};

      await pump(tester);
      await fillTheRequiredAnswers(tester);

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      expect(find.textContaining('wait a minute'), findsOneWidget);
    });

    testWidgets('switching back to new student drops the transferee answers', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Transferring in'));
      await tester.pumpAndSettle();
      await fillTheRequiredAnswers(tester);
      await type(tester, 'apply:previousCollege', 'Some University');
      await choose(tester, 'apply_year_level_picker', '3rd year');

      await tester.tap(find.text('New student'));
      await tester.pumpAndSettle();

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      final form = sentForm()['form'] as Map<String, dynamic>;
      expect(form['studentType'], 1);
      // Hidden is not enough: left in, these read like somebody with credits to record.
      expect(form.containsKey('previousCollege'), false);
      expect(form.containsKey('previousCourse'), false);
      expect(form.containsKey('previousStudentID'), false);
      expect(form.containsKey('yearLevel'), false);
    });

    testWidgets('the whole form fits a phone screen without overflowing', (tester) async {
      await pump(tester, width: 360);
      await tester.tap(find.text('Transferring in'));
      await tester.pumpAndSettle();

      // Every section has to lay out, including the ones only a transferee sees.
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
        await tester.pump();
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('a failed submit brings the first unanswered question into view', (tester) async {
      await pump(tester, width: 360);

      // Answer the first section fully, leave the next one empty, and submit from the bottom.
      await type(tester, 'apply_email', 'applicant@example.com');
      await choose(tester, 'apply_course_picker', 'BSIT — BS Information Technology');
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
        await tester.pump();
      }

      final nationality = find.byKey(const ValueKey('apply:nationality'));
      expect(nationality, findsOneWidget);
      final before = tester.getTopLeft(nationality).dy;

      await act(tester, () async {
        await tester.tap(find.byKey(const ValueKey('apply_submit_button')));
      });

      // 'About you' holds the first missing answer, so the page came back up to it.
      final after = tester.getTopLeft(nationality).dy;
      expect(after, greaterThan(before));
      expect(after, lessThan(tester.view.physicalSize.height));
      expect(requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('there is always a way back to sign in', (tester) async {
      await pump(tester);

      await tester.tap(find.byKey(const ValueKey('apply_back_button')));
      await tester.pumpAndSettle();

      expect(backToSignIn, 1);
    });
  });

  group('the way in from the sign-in page', () {
    testWidgets('the Enroll button opens the form', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      var opened = 0;
      await tester.pumpWidget(signInPage(onApply: () => opened++));
      await tester.pumpAndSettle();

      final button = find.byKey(const ValueKey('enroll_button'));
      expect(button, findsOneWidget);
      expect(find.text('Not a student here yet?'), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(opened, 1);
    });

    testWidgets('nothing is offered when there is nowhere for it to go', (tester) async {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(signInPage());
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('enroll_button')), findsNothing);
    });
  });
}
