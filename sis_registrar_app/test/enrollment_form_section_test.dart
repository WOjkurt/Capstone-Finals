import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/enrollment_models.dart';
import 'package:sis_registrar_app/views/widgets/enrollment_form_section.dart';

EnrollmentApplicationModel _app() => EnrollmentApplicationModel.fromJson({
      'applicationID': 'a1',
      'createdAt': '2026-06-15T06:30:00Z',
      'form': {
        'firstName': 'Ana', 'lastName': 'Cruz', 'studentType': 2, 'civilStatus': 'Single',
        'mobileNumber': '9171234567', 'houseStreet': '12 Rizal St.', 'barangay': 'Lahug',
        'cityMunicipality': 'Cebu City', 'province': 'Cebu', 'zipCode': '6000',
        'lastSchoolAttended': 'Cebu NHS', 'yearGraduated': '2022-01-01', 'dateOfBirth': '2004-01-01',
        'previousCollege': '', 'familyMedicalConditionsSelected': ['Asthma', 'Allergies'],
      },
      'contacts': [
        {'firstName': 'Rosa', 'lastName': 'Cruz', 'relationType': 2, 'occupation': 'Vendor', 'contactNo': '9181111111'},
        {'firstName': 'Juan', 'lastName': 'Cruz', 'relationType': 1, 'occupation': '', 'contactNo': ''},
        {'firstName': 'Lito', 'lastName': 'Reyes', 'relationType': 3, 'occupation': '', 'contactNo': '',
         'guardianRelationshipDescription': 'Uncle', 'livingWithGuardian': true},
      ],
    });

Future<void> _pump(WidgetTester tester, Future<EnrollmentApplicationModel?> Function(String) load) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: EnrollmentFormSection(userId: 'u1', load: load))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts collapsed; opening it shows the answers with father, mother, then guardian', (tester) async {
    await _pump(tester, (_) async => _app());

    expect(find.text('Enrollment form'), findsOneWidget);
    expect(find.text('Cebu NHS'), findsNothing); // collapsed

    await tester.tap(find.byKey(const ValueKey('enrollment_form_tile')));
    await tester.pumpAndSettle();

    expect(find.text('Old'), findsOneWidget);
    expect(find.text('12 Rizal St., Lahug, Cebu City, Cebu, 6000'), findsOneWidget);
    expect(find.text('Cebu NHS'), findsOneWidget);
    expect(find.text('2022'), findsOneWidget);
    expect(find.text('Asthma, Allergies'), findsOneWidget);
    expect(find.text('Rosa Cruz · 9181111111 · Vendor'), findsOneWidget);
    expect(find.text('Guardian (Uncle)'), findsOneWidget);
    expect(find.text('Lito Reyes · student lives with guardian'), findsOneWidget);

    final father = tester.getTopLeft(find.text('Father')).dy;
    final mother = tester.getTopLeft(find.text('Mother')).dy;
    final guardian = tester.getTopLeft(find.text('Guardian (Uncle)')).dy;
    expect(father < mother && mother < guardian, isTrue);
  });

  testWidgets('a student without a form shows nothing', (tester) async {
    await _pump(tester, (_) async => null);
    expect(find.byKey(const ValueKey('enrollment_form_section')), findsNothing);
  });
}
