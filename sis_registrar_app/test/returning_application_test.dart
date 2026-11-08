import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/blocs/applications_bloc.dart';
import 'package:sis_registrar_app/models/enrollment_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/views/applications_view.dart';

class _Bloc extends Bloc<ApplicationsEvent, ApplicationsState> implements ApplicationsBloc {
  _Bloc(super.initialState) {
    on<ApplicationsEvent>((e, emit) {});
  }
}

EnrollmentApplicationModel app({bool returning = true, List<String> changed = const []}) => EnrollmentApplicationModel(
      applicationId: 'a1',
      responseId: 'r1',
      programId: 1,
      termId: 't2',
      status: 1,
      createdAt: DateTime(2026, 11, 20),
      isReturning: returning,
      changedFields: changed,
      form: const EnrollmentFormModel(
        firstName: 'Ana', middleName: 'Santos', lastName: 'Cruz', suffix: '', dateOfBirth: '2006-03-14',
        placeOfBirth: 'Cebu City', sex: 'Female', civilStatus: 'Single', nationality: 'Filipino',
        mobileNumber: '09189999999', barangay: 'Inayawan', cityMunicipality: 'Cebu City', province: 'Cebu',
        zipCode: '6000', lastSchoolAttended: 'Abellana NHS', schoolAddress: 'Cebu', programTrackStrand: 'STEM',
        yearGraduated: '2025-03-01', previousCollege: '', previousCourse: '', yearLevel: 2,
      ),
    );

void main() {
  test('reads the returning flag and changed fields', () {
    final a = EnrollmentApplicationModel.fromJson({
      'applicationID': 'a1', 'responseID': 'r1', 'programID': 1, 'termID': 't2', 'status': 1,
      'createdAt': '2026-11-20T00:00:00Z', 'isReturning': true, 'changedFields': ['Mobile Number', 'Father'],
    });
    expect(a.isReturning, isTrue);
    expect(a.changedFields, ['Mobile Number', 'Father']);
    expect(EnrollmentApplicationModel.fromJson({'createdAt': '2026-11-20T00:00:00Z'}).isReturning, isFalse);
  });

  Future<void> pump(WidgetTester tester, EnrollmentApplicationModel a) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final bloc = _Bloc(ApplicationsLoaded(
      applications: [a],
      programs: const [AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'Information Technology')],
      terms: const [AcademicTermModel(termId: 't2', schoolYear: '2026-2027', semester: 2)],
    ));
    addTearDown(bloc.close);
    await tester.pumpWidget(MaterialApp(home: BlocProvider<ApplicationsBloc>.value(value: bloc, child: const ApplicationsView())));
    await tester.pumpAndSettle();
  }

  testWidgets('a returning student is labelled, and Review highlights what changed', (tester) async {
    await pump(tester, app(changed: ['Mobile Number', 'Barangay', 'Father']));
    expect(find.text('Returning'), findsOneWidget);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('returning_banner')), findsOneWidget);
    expect(find.textContaining('Mobile Number, Barangay, Father'), findsOneWidget);
    expect(find.byKey(const ValueKey('changed_Mobile Number')), findsOneWidget);
    expect(find.byKey(const ValueKey('changed_Barangay')), findsOneWidget);
    expect(find.byKey(const ValueKey('changed_Province')), findsNothing);
  });

  testWidgets('Approve explains that no login is needed', (tester) async {
    await pump(tester, app());
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('approve_returning_note')), findsOneWidget);
    expect(find.textContaining('No changes since the last enrollment'), findsOneWidget);
  });

  testWidgets('a new student has no Returning label', (tester) async {
    await pump(tester, app(returning: false));
    expect(find.text('Returning'), findsNothing);
  });
}
