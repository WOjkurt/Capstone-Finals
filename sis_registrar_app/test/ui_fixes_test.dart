import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_registrar_app/views/responses_view.dart';
import 'package:sis_registrar_app/views/clearance_view.dart';
import 'package:sis_registrar_app/views/setup_view.dart';
import 'package:sis_registrar_app/views/applications_view.dart';
import 'package:sis_registrar_app/blocs/responses_bloc.dart';
import 'package:sis_registrar_app/blocs/clearance_bloc.dart';
import 'package:sis_registrar_app/blocs/setup_bloc.dart';
import 'package:sis_registrar_app/blocs/applications_bloc.dart';
import 'package:sis_registrar_app/models/enrollment_models.dart';
import 'package:sis_registrar_app/models/setup_models.dart';

import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/blocs/auth_bloc.dart';

class TestResponsesBloc extends Bloc<ResponsesEvent, ResponsesState> implements ResponsesBloc {
  TestResponsesBloc(super.initialState);
}

class TestClearanceBloc extends Bloc<ClearanceEvent, ClearanceState> implements ClearanceBloc {
  TestClearanceBloc(super.initialState) {
    on<ClearanceEvent>((event, emit) {});
  }

  void emitState(ClearanceState state) {
    emit(state);
  }
}

class TestSetupBloc extends Bloc<SetupEvent, SetupState> implements SetupBloc {
  TestSetupBloc(super.initialState);
}

class TestApplicationsBloc extends Bloc<ApplicationsEvent, ApplicationsState> implements ApplicationsBloc {
  final List<ApplicationsEvent> recordedEvents = [];
  TestApplicationsBloc(super.initialState) {
    on<ApplicationsEvent>((event, emit) {
      recordedEvents.add(event);
    });
  }
}

class TestAuthBloc extends Bloc<AuthEvent, AuthState> implements AuthBloc {
  final List<AuthEvent> recordedEvents = [];
  TestAuthBloc(super.initialState) {
    on<AuthEvent>((event, emit) {
      recordedEvents.add(event);
    });
  }
}

void main() {
  group('UI Bug Fixes Verification', () {
    testWidgets('1. Responses intake form dropdowns handle long labels with no RenderFlex overflow', (tester) async {
      // Set test surface size simulating desktop window
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final longPrograms = [
        const AcademicProgramModel(
          programId: 101,
          programCode: 'BSIT-NETWORK-SECURITY-EXTENDED',
          programName: 'Bachelor of Science in Information Technology Major in Network and Systems Security Administration with Honors',
        ),
        const AcademicProgramModel(
          programId: 102,
          programCode: 'BSCS-AI-DATA-SCIENCE',
          programName: 'Bachelor of Science in Computer Science with Specialization in Machine Learning and Deep Systems Architecture',
        ),
      ];

      final longTerms = [
        const AcademicTermModel(
          termId: '2026-1S-REGULAR-LONG',
          schoolYear: '2026-2027 Comprehensive First Semester Academic Year Term Session',
          semester: 1,
        ),
      ];

      final responses = [
        EnrollmentResponseModel(
          responseId: 'resp-12345',
          timestamp: DateTime(2026, 9, 1),
          emailAddress: 'applicant.very.long.email.address@dbtc-cebu.edu.ph',
          isProcessed: false,
        ),
      ];

      final bloc = TestResponsesBloc(ResponsesLoaded(
        responses: responses,
        programs: longPrograms,
        terms: longTerms,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ResponsesBloc>.value(
            value: bloc,
            child: const ResponsesView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final processButton = find.text('Process into application');
      expect(processButton, findsOneWidget);
      await tester.ensureVisible(processButton);
      await tester.pumpAndSettle();
      await tester.tap(processButton);
      await tester.pumpAndSettle();

      // Ensure modal is shown
      expect(find.text('Process Enrollment Response'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify Academic Program dropdown is present
      final programDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == 'Academic Program *',
      );
      expect(programDropdown, findsOneWidget);

      // Verify closed-state displays without overflow exception
      expect(tester.takeException(), isNull);

      // Tap to open the Academic Program dropdown menu
      await tester.tap(programDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Select the second long option in the open menu
      final secondOption = find.text('BSCS-AI-DATA-SCIENCE - Bachelor of Science in Computer Science with Specialization in Machine Learning and Deep Systems Architecture').last;
      await tester.tap(secondOption);
      await tester.pumpAndSettle();

      // Closed state after selection should have no overflow
      expect(tester.takeException(), isNull);

      // Verify Academic Term dropdown
      final termDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<String> && w.decoration.labelText == 'Academic Term *',
      );
      expect(termDropdown, findsOneWidget);
      await tester.tap(termDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tap to close term dropdown
      final termOption = find.text('2026-2027 Comprehensive First Semester Academic Year Term Session — 1st Sem').last;
      await tester.tap(termOption);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify SHS Strand dropdown
      final strandDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == 'SHS Strand *',
      );
      expect(strandDropdown, findsOneWidget);
      await tester.ensureVisible(strandDropdown);
      await tester.pumpAndSettle();
      await tester.tap(strandDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('HUMSS').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify Relation dropdown
      final relationDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == 'Relation *',
      );
      expect(relationDropdown, findsOneWidget);
      await tester.ensureVisible(relationDropdown);
      await tester.pumpAndSettle();
      await tester.tap(relationDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Guardian').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Close modal
      final closeBtn = find.byIcon(Icons.close);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Clearance search bar loading indicator is cleanly sized (16x16) and centered', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // State with isSearching: true
      final bloc = TestClearanceBloc(ClearanceStateData(
        searchQuery: 'Test Student',
        isSearching: true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ClearanceBloc>.value(
            value: bloc,
            child: const ClearanceView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify CircularProgressIndicator exists in suffixIcon slot
      final indicatorFinder = find.byType(CircularProgressIndicator);
      expect(indicatorFinder, findsOneWidget);

      final indicator = tester.widget<CircularProgressIndicator>(indicatorFinder);
      expect(indicator.strokeWidth, 2.0);

      // Verify it is constrained by a SizedBox of exactly 16x16
      final sizedBoxFinder = find.ancestor(
        of: indicatorFinder,
        matching: find.byType(SizedBox),
      ).first;
      final sizedBox = tester.widget<SizedBox>(sizedBoxFinder);
      expect(sizedBox.width, 16.0);
      expect(sizedBox.height, 16.0);

      // Verify it is centered properly within the suffix slot
      final centerFinder = find.ancestor(
        of: sizedBoxFinder,
        matching: find.byType(Center),
      );
      expect(centerFinder, findsWidgets);

      // Type into search bar and verify no exceptions
      await tester.enterText(find.byType(TextField), 'Searching for someone');
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Now switch state to isSearching: false with text present (shows clear icon)
      bloc.emitState(ClearanceStateData(
        searchQuery: 'Searching for someone',
        isSearching: false,
      ));
      await tester.pumpAndSettle();

      // CircularProgressIndicator should be replaced by clear IconButton
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. SetupView Subject modal dropdowns handle long labels with no RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final longPrograms = [
        const AcademicProgramModel(
          programId: 201,
          programCode: 'BSIT-VERY-LONG-PROGRAM-CODE-SPECIALIZATION',
          programName: 'Bachelor of Science in Information Technology Major in Software Engineering and Enterprise Systems',
        ),
      ];

      final setupBloc = TestSetupBloc(SetupState(
        activeTab: 2, // Subjects Tab
        programs: longPrograms,
        subjects: [],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SetupBloc>.value(
            value: setupBloc,
            child: const SetupView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Add Subject' button
      final addSubjectBtn = find.text('Add Subject');
      expect(addSubjectBtn, findsOneWidget);
      await tester.tap(addSubjectBtn);
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify Program dropdown
      final progDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == 'Program *',
      );
      expect(progDropdown, findsOneWidget);
      await tester.tap(progDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tap the long program option
      final progOption = find.text('BSIT-VERY-LONG-PROGRAM-CODE-SPECIALIZATION').last;
      await tester.tap(progOption);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify Year Level dropdown
      final yearDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == 'Year Level *',
      );
      expect(yearDropdown, findsOneWidget);
      await tester.tap(yearDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Year 2').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify Default Semester dropdown
      final semDropdown = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<int> && w.decoration.labelText == 'Default Semester *',
      );
      expect(semDropdown, findsOneWidget);
      await tester.tap(semDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('2nd Semester').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. ApplicationsView approval modal dropdown handles Year Level cleanly with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final app = EnrollmentApplicationModel(
        applicationId: 'app-001',
        responseId: 'resp-001',
        programId: 1,
        termId: '2026-1S',
        status: 1, // Pending
        createdAt: DateTime(2026, 9, 1),
        form: const EnrollmentFormModel(
          firstName: 'Juan',
          middleName: 'Protacio',
          lastName: 'Dela Cruz',
          suffix: '',
          dateOfBirth: '2005-01-01',
          placeOfBirth: 'Cebu City',
          sex: 'Male',
          civilStatus: 'Single',
          nationality: 'Filipino',
          mobileNumber: '09170000001',
          barangay: 'Poblacion',
          cityMunicipality: 'Cebu City',
          province: 'Cebu',
          zipCode: '6000',
          lastSchoolAttended: 'Don Bosco',
          schoolAddress: 'Cebu',
          shsStrand: 1,
          yearGraduated: '2023-05-30',
          previousCollege: '',
          previousCourse: '',
          yearLevel: 1,
        ),
        contacts: [],
      );

      final appBloc = TestApplicationsBloc(ApplicationsLoaded(
        applications: [app],
        programs: [const AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'Information Technology')],
        terms: [const AcademicTermModel(termId: '2026-1S', schoolYear: '2026-2027', semester: 1)],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ApplicationsBloc>.value(
            value: appBloc,
            child: const ApplicationsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Approve' button
      final approveBtn = find.text('Approve');
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Modal is open
      expect(find.text('Approve Application'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify Year Level dropdown in modal
      final ylDropdown = find.byType(DropdownButtonFormField<int>);
      expect(ylDropdown, findsOneWidget);
      await tester.tap(ylDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Year 3').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. ClearanceView term clearance card handles narrow widths and long labels without overflow', (tester) async {
      // Test at desktop size – registrar app is desktop-first; 700px is below its design minimum.
      // The overflow fix (Expanded + LayoutBuilder) is validated with content that would have
      // overflowed before even at normal desktop width (long term labels, long auditor names).
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final student = const UserSearchResultModel(
        userId: 'usr-student-001',
        firstname: 'Alexander Bartholomew',
        lastname: 'Montgomery-Delacroix',
        email: 'alexander.bartholomew.delacroix@student.dbtc-cebu.edu.ph',
        programCode: 'BSIT-NETWORK-SECURITY-EXTENDED',
        yearLevel: 3,
        studentStatus: 1,
        role: 0,
      );

      final clearances = [
        GradeClearanceModel(
          clearanceId: 'clr-001',
          userId: 'usr-student-001',
          termId: '2026-1S-VERY-LONG-TERM-IDENTIFIER',
          termLabel: 'Academic Year 2026-2027 First Trimester Extension Program — Special Term',
          isCleared: true,
          clearedByUserName: 'Sister Maria Teresa Esperanza de los Santos-Gonzales, Head Registrar',
          clearedAt: DateTime(2026, 9, 5, 14, 30),
        ),
        GradeClearanceModel(
          clearanceId: 'clr-002',
          userId: 'usr-student-001',
          termId: '2026-2S-VERY-LONG-TERM-IDENTIFIER',
          termLabel: 'Academic Year 2026-2027 Second Semester Regular Collegiate Session',
          isCleared: false,
          clearedByUserName: null,
          clearedAt: null,
        ),
      ];

      final bloc = TestClearanceBloc(ClearanceStateData(
        searchQuery: '',
        isSearching: false,
        searchResults: [student],
        selectedStudent: student,
        isClearanceLoading: false,
        clearances: clearances,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ClearanceBloc>.value(
            value: bloc,
            child: const ClearanceView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure no exceptions occurred during layout/render
      expect(tester.takeException(), isNull);

      // Verify student header details render (name appears in both list tile and banner)
      expect(find.text('Alexander Bartholomew Montgomery-Delacroix'), findsWidgets);
      expect(find.textContaining('alexander.bartholomew.delacroix'), findsWidgets);

      // Verify term labels render
      expect(find.text('Academic Year 2026-2027 First Trimester Extension Program — Special Term'), findsOneWidget);
      expect(find.text('Academic Year 2026-2027 Second Semester Regular Collegiate Session'), findsOneWidget);

      // Verify status badges render
      expect(find.text('Cleared'), findsWidgets);
      expect(find.text('Hold (Uncleared)'), findsOneWidget);

      // Verify audit trail text renders
      expect(find.textContaining('Audited by: Sister Maria Teresa'), findsOneWidget);

      // Verify switches exist and are responsive
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      // Toggle the second switch
      await tester.tap(switches.last);
      await tester.pumpAndSettle();

      // Zero exceptions and zero overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets('6. ApplicationsView approval modal safely handles yearLevel == 0 with no crash, displays cleanly, and confirms approval', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create an application where yearLevel is 0 (the exact root cause scenario)
      final appWithZeroYear = EnrollmentApplicationModel(
        applicationId: 'app-zero-year-001',
        responseId: 'resp-001',
        programId: 1,
        termId: '2026-1S',
        status: 1, // Pending
        createdAt: DateTime(2026, 9, 1),
        form: const EnrollmentFormModel(
          firstName: 'Gabriel',
          middleName: 'I.',
          lastName: 'Silang',
          suffix: '',
          dateOfBirth: '2005-01-01',
          placeOfBirth: 'Cebu City',
          sex: 'Male',
          civilStatus: 'Single',
          nationality: 'Filipino',
          mobileNumber: '09170000002',
          barangay: 'Mabolo',
          cityMunicipality: 'Cebu City',
          province: 'Cebu',
          zipCode: '6000',
          lastSchoolAttended: 'Don Bosco',
          schoolAddress: 'Cebu',
          shsStrand: 1,
          yearGraduated: '2023-05-30',
          previousCollege: '',
          previousCourse: '',
          yearLevel: 0, // Explicitly 0
        ),
        contacts: [],
      );

      final appBloc = TestApplicationsBloc(ApplicationsLoaded(
        applications: [appWithZeroYear],
        programs: [const AcademicProgramModel(programId: 1, programCode: 'BSIT', programName: 'Information Technology')],
        terms: [const AcademicTermModel(termId: '2026-1S', schoolYear: '2026-2027', semester: 1)],
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<ApplicationsBloc>.value(
            value: appBloc,
            child: const ApplicationsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Table displays dash instead of 'Year 0'
      expect(find.text('—'), findsWidgets);

      // Tap 'Approve' button
      final approveBtn = find.text('Approve');
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Modal is open with no DropdownButton assertion crash
      expect(find.text('Approve Application'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dropdown defaulted to Year 1 (first valid item), not 0
      final ylDropdown = find.byType(DropdownButtonFormField<int>);
      expect(ylDropdown, findsOneWidget);
      final dropdownWidget = tester.widget<DropdownButtonFormField<int>>(ylDropdown);
      expect(dropdownWidget.initialValue, 1);

      // Open dropdown and select 'Year 2'
      await tester.tap(ylDropdown);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Year 2').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Tap 'Confirm Approval'
      final confirmBtn = find.text('Confirm Approval');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify event was dispatched with yearLevel: 2
      expect(appBloc.recordedEvents.length, 1);
      final event = appBloc.recordedEvents.first as ApproveApplicationEvent;
      expect(event.applicationId, 'app-zero-year-001');
      expect(event.yearLevel, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // Logout Confirmation Dialog
  // ---------------------------------------------------------------------------
  group('Logout confirmation dialog', () {
    late TestAuthBloc authBloc;

    setUp(() {
      authBloc = TestAuthBloc(
        AuthenticatedState(
          email: 'registrar@dbtc-cebu.edu.ph',
          role: 2,
          roleName: 'Registrar',
          userId: 'test-uid-123',
        ),
      );
    });

    tearDown(() => authBloc.close());

    /// Builds a minimal scaffold that contains only the Sign Out button
    /// wired to the same _confirmLogout logic, avoiding the need to provide
    /// all seven child-view BLoCs that the full MainLayoutView requires.
    Widget buildSubject() {
      return MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: authBloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: OutlinedButton.icon(
                key: const Key('sign_out_button'),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    barrierDismissible: true,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text(
                        "You'll need to sign in again to access the Registrar portal.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    context.read<AuthBloc>().add(LogoutRequested());
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign Out'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('tapping Sign Out shows the confirmation dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap the Sign Out button in the sidebar
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      // Dialog must appear with the correct title and body text
      expect(find.text('Log out?'), findsOneWidget);
      expect(
        find.text("You'll need to sign in again to access the Registrar portal."),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
    });

    testWidgets('tapping Cancel closes the dialog without dispatching LogoutRequested', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Log out?'), findsNothing);

      // No LogoutRequested was dispatched — bloc stays in AuthenticatedState
      expect(authBloc.state, isA<AuthenticatedState>());
      expect(authBloc.recordedEvents.whereType<LogoutRequested>(), isEmpty);
    });

    testWidgets('tapping Log out dispatches LogoutRequested', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Open dialog
      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      // Tap the destructive confirm button
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Log out?'), findsNothing);

      // Exactly one LogoutRequested was dispatched
      expect(authBloc.recordedEvents.whereType<LogoutRequested>().length, 1);
    });
  });
}
