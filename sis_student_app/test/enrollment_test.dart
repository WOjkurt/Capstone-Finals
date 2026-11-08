import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sis_student_app/models/reenrollment_models.dart';
import 'package:sis_student_app/repositories/reenrollment_repository.dart';
import 'package:sis_student_app/services/auth_service.dart';
import 'package:sis_student_app/theme/app_theme.dart';
import 'package:sis_student_app/views/enrollment_view.dart';
import 'package:sis_student_app/views/widgets/idle_sign_out.dart';

class FakeAuthService implements AuthService {
  @override
  Future<Map<String, String>> getAuthHeaders() async => {'Authorization': 'Bearer t'};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> readyStatus() => {
      'state': 'Ready',
      'reasons': <String>[],
      'termId': 't2',
      'termLabel': '2026-2027 (2nd Sem)',
      'opensOn': '2026-11-17',
      'closesOn': '2026-11-28',
      'programCode': 'BSIT',
      'programName': 'BS Information Technology',
      'currentYearLevel': 2,
      'yearLevelChoices': [2, 3],
      'lockedFields': ['FirstName', 'MiddleName', 'LastName', 'Suffix', 'DateOfBirth', 'PlaceOfBirth', 'Sex', 'LRN'],
      'filledFromTerm': '2026-2027 (1st Sem)',
      'form': {
        'firstName': 'Juan', 'middleName': 'Santos', 'lastName': 'Dela Cruz', 'suffix': 'N/A',
        'dateOfBirth': '2006-03-14', 'placeOfBirth': 'Cebu City', 'sex': 'Male', 'civilStatus': 'Single',
        'nationality': 'Filipino', 'religion': 'Roman Catholic', 'mobileNumber': '09171111111',
        'barangay': 'Pardo', 'cityMunicipality': 'Cebu City', 'cityOfMunicipality': 'Cebu City',
        'province': 'Cebu', 'zipCode': '6000', 'lrn': '123456789012', 'yearLevel': 2,
        'lastSchoolAttended': 'Abellana NHS', 'schoolAddress': 'Cebu City', 'previousCollege': 'N/A',
        'previousCourse': 'N/A', 'yearGraduated': '2025-03-01',
      },
      'contacts': [
        {'firstName': 'Pedro', 'lastName': 'Dela Cruz', 'relationType': 1, 'contactNo': '09170000001'},
        {'firstName': 'Maria', 'lastName': 'Dela Cruz', 'relationType': 2, 'contactNo': '09170000002'},
      ],
    };

void main() {
  test('locked field names match the form keys', () {
    final s = ReenrollmentStatus.fromJson({'state': 'Ready', 'lockedFields': ['FirstName', 'LRN', 'PreviousStudentID']});
    expect(s.lockedFields, {'firstName', 'lrn', 'previousStudentID'});
  });

  late List<http.Request> requests;
  late List<Map<String, dynamic>> answers;

  Future<void> pump(WidgetTester tester, List<Map<String, dynamic>> statuses, {double width = 1280}) async {
    requests = [];
    answers = List.of(statuses);
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await http.runWithClient(() async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: EnrollmentView(repository: ReenrollmentRepository(FakeAuthService())),
      ));
      await tester.pumpAndSettle();
    }, () => MockClient((req) async {
          requests.add(req);
          if (req.method == 'POST') {
            return http.Response(jsonEncode({'message': 'Your enrollment for 2026-2027 (2nd Sem) was sent to the Registrar.'}), 200);
          }
          final next = answers.length > 1 ? answers.removeAt(0) : answers.first;
          return http.Response(jsonEncode(next), 200);
        }));
  }

  Future<void> act(WidgetTester tester, Future<void> Function() action) async {
    await http.runWithClient(() async {
      await action();
      await tester.pumpAndSettle();
    }, () => MockClient((req) async {
          requests.add(req);
          if (req.method == 'POST') {
            return http.Response(jsonEncode({'message': 'Your enrollment for 2026-2027 (2nd Sem) was sent to the Registrar.'}), 200);
          }
          final next = answers.length > 1 ? answers.removeAt(0) : answers.first;
          return http.Response(jsonEncode(next), 200);
        }));
  }

  testWidgets('closed', (tester) async {
    await pump(tester, [{'state': 'Closed'}]);
    expect(find.byKey(const ValueKey('enrollment_closed')), findsOneWidget);
  });

  testWidgets('on hold shows the reasons', (tester) async {
    await pump(tester, [
      {
        'state': 'OnHold', 'termLabel': '2026-2027 (2nd Sem)', 'closesOn': '2026-11-28',
        'reasons': ['You are not yet cleared for 2026-2027 (1st Sem).', 'You have a hold: Unpaid balance.', 'Please see the Registrar.'],
      }
    ]);
    expect(find.byKey(const ValueKey('enrollment_on_hold')), findsOneWidget);
    expect(find.text('You have a hold: Unpaid balance.'), findsOneWidget);
    expect(find.textContaining('closes on Nov 28, 2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('start_enrollment_button')), findsNothing);
  });

  testWidgets('submitted shows where it is', (tester) async {
    await pump(tester, [
      {'state': 'Submitted', 'termLabel': '2026-2027 (2nd Sem)', 'submittedAt': '2026-11-20T07:00:00Z', 'applicationStatus': 'Pending'}
    ]);
    expect(find.text('Waiting for the Registrar'), findsOneWidget);
    expect(find.textContaining('Sent on Nov 20, 2026'), findsOneWidget);
  });

  Finder stepTitle(String text) =>
      find.byWidgetPredicate((w) => w is Text && w.key == const ValueKey('step_title') && w.data == text);

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('next_button')));
    await tester.pumpAndSettle();
  }

  testWidgets('five steps: locked fields, checks per step, the review and sending', (tester) async {
    final status = readyStatus();
    await pump(tester, [
      status,
      {'state': 'Submitted', 'termLabel': '2026-2027 (2nd Sem)', 'submittedAt': '2026-11-20T07:00:00Z', 'applicationStatus': 'Pending'},
    ]);
    expect(find.text('Enrollment for 2026-2027 (2nd Sem) is open'), findsOneWidget);
    expect(find.textContaining('until Nov 28, 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('start_enrollment_button')));
    await tester.pumpAndSettle();

    // Step 1: name and LRN are shown but cannot be typed in.
    expect(stepTitle('Step 1 of 5 · Personal information'), findsOneWidget);
    expect(find.byKey(const ValueKey('back_button')), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('f:firstName')), matching: find.text('Juan')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('f:firstName')), matching: find.byType(EditableText)), findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('f:lrn')), matching: find.byType(EditableText)), findsNothing);
    expect(find.text('Mar 14, 2006'), findsOneWidget);
    await next(tester);

    // Step 2: a bad mobile number stops Next on this step.
    expect(stepTitle('Step 2 of 5 · Contact and address'), findsOneWidget);
    expect(find.byKey(const ValueKey('f:provBarangay')), findsNothing); // folded away until asked for
    await tester.enterText(find.byKey(const ValueKey('f:mobileNumber')), '0918');
    await next(tester);
    expect(find.text('11 digits starting with 09, e.g. 09171234567'), findsOneWidget);
    expect(stepTitle('Step 2 of 5 · Contact and address'), findsOneWidget);
    expect(find.byKey(const ValueKey('step_error')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('f:mobileNumber')), '09189999999');
    await tester.enterText(find.byKey(const ValueKey('f:cityMunicipality')), 'Talisay City');
    await tester.tap(find.byKey(const ValueKey('add_provincial_address')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('f:provBarangay')), findsOneWidget);
    await next(tester);

    // Step 3: one card per parent; Edit opens the fields.
    expect(stepTitle('Step 3 of 5 · Parents and guardian'), findsOneWidget);
    expect(find.byKey(const ValueKey('contact_card_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('c1:contactNo')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('edit_contact_1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('c1:contactNo')), '09170000099');
    await tester.pumpAndSettle();
    expect(find.textContaining('changed'), findsWidgets);
    await next(tester);

    expect(stepTitle('Step 4 of 5 · Family and health'), findsOneWidget);
    await next(tester);

    // Step 5: the review lists the changes; a change jumps back to its step.
    expect(stepTitle('Step 5 of 5 · Review and send'), findsOneWidget);
    for (final label in ['Mobile number', 'City / municipality', 'Father']) {
      expect(find.byKey(ValueKey('change_$label')), findsOneWidget);
    }
    expect(tester.widget<FilledButton>(find.byKey(const ValueKey('send_enrollment_button'))).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('change_Father')));
    await tester.pumpAndSettle();
    expect(stepTitle('Step 3 of 5 · Parents and guardian'), findsOneWidget);
    await next(tester);
    await next(tester);

    await tester.tap(find.byKey(const ValueKey('confirm_checkbox')));
    await tester.pumpAndSettle();
    await act(tester, () => tester.tap(find.byKey(const ValueKey('send_enrollment_button'))));

    final post = requests.singleWhere((r) => r.method == 'POST');
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['termId'], 't2');
    expect(body['yearLevel'], 2);
    expect(body['confirmed'], true);
    expect(body['form']['mobileNumber'], '09189999999');
    expect(body['form']['cityMunicipality'], 'Talisay City');
    expect((body['form'] as Map).containsKey('cityOfMunicipality'), isFalse);
    expect(body['form']['firstName'], 'Juan');
    expect((body['contacts'] as List).first['contactNo'], '09170000099');
    expect(body.keys, isNot(contains('userId')));

    expect(find.byKey(const ValueKey('enrollment_submitted')), findsOneWidget);
  });

  testWidgets('a mistake in a folded parent card opens it on Next', (tester) async {
    final status = readyStatus();
    (status['contacts'] as List).first['contactNo'] = '0917';
    await pump(tester, [status]);
    await tester.tap(find.byKey(const ValueKey('start_enrollment_button')));
    await tester.pumpAndSettle();
    await next(tester);
    await next(tester);
    expect(find.byKey(const ValueKey('c1:contactNo')), findsNothing);
    await next(tester);
    expect(stepTitle('Step 3 of 5 · Parents and guardian'), findsOneWidget);
    expect(find.byKey(const ValueKey('c1:contactNo')), findsOneWidget);
    expect(find.text('Mobile like 09171234567 or landline like 0322531234'), findsOneWidget);
  });

  testWidgets('a provincial address on file is shown without asking', (tester) async {
    final status = readyStatus();
    (status['form'] as Map)['provBarangay'] = 'Poblacion';
    await pump(tester, [status]);
    await tester.tap(find.byKey(const ValueKey('start_enrollment_button')));
    await tester.pumpAndSettle();
    await next(tester);
    expect(find.byKey(const ValueKey('f:provBarangay')), findsOneWidget);
    expect(find.byKey(const ValueKey('add_provincial_address')), findsNothing);
  });

  testWidgets('cancel with changes asks first, then goes back to the start', (tester) async {
    await pump(tester, [readyStatus()]);
    await tester.tap(find.byKey(const ValueKey('start_enrollment_button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('f:religion')), 'Christian');
    await tester.pumpAndSettle();
    // The reload after leaving belongs to the Cancel tap, so both run with the fake API.
    await act(tester, () async {
      await tester.tap(find.byKey(const ValueKey('cancel_enrollment_button')));
      await tester.pumpAndSettle();
      expect(find.text('Leave without sending?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('confirm_leave_button')));
    });
    expect(find.byKey(const ValueKey('enrollment_open_banner')), findsOneWidget);
    expect(requests.where((r) => r.method == 'POST'), isEmpty);
  });

  for (final width in [320.0, 412.0]) {
    testWidgets('phone ($width): every step fits', (tester) async {
      await pump(tester, [readyStatus()], width: width);
      await tester.tap(find.byKey(const ValueKey('start_enrollment_button')));
      await tester.pumpAndSettle();
      // Locked fields are one short card on a phone, not a box each.
      expect(find.byKey(const ValueKey('locked_card')), findsOneWidget);
      expect(find.byKey(const ValueKey('f:firstName')), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('locked:dateOfBirth')), matching: find.text('Mar 14, 2006')), findsOneWidget);
      for (var i = 0; i < 4; i++) {
        if (i == 2) {
          await tester.tap(find.byKey(const ValueKey('edit_contact_1')));
          await tester.pumpAndSettle();
        }
        await next(tester);
      }
      expect(stepTitle('Step 5 of 5 · Review and send'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('laptop keeps the locked fields as boxes in the grid', (tester) async {
    await pump(tester, [readyStatus()]);
    await tester.tap(find.byKey(const ValueKey('start_enrollment_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('locked_card')), findsNothing);
    expect(find.byKey(const ValueKey('f:firstName')), findsOneWidget);
  });

  testWidgets('idle sign-out after the time with no activity; a tap starts the wait again', (tester) async {
    var signedOut = 0;
    await tester.pumpWidget(MaterialApp(
      home: IdleSignOut(
        timeout: const Duration(seconds: 10),
        onTimeout: () => signedOut++,
        child: const Scaffold(body: SizedBox.expand()),
      ),
    ));
    await tester.pump(const Duration(seconds: 8));
    await tester.tapAt(const Offset(50, 50));
    await tester.pump(const Duration(seconds: 8));
    expect(signedOut, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(signedOut, 1);
  });
}
