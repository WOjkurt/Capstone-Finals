import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/models/staff_model.dart';
import 'package:sis_registrar_app/blocs/staff_bloc.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/repositories/staff_repository.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';
import 'package:sis_registrar_app/views/staff_management_view.dart';

class FakeAcademicSetupRepository implements AcademicSetupRepository {
  @override
  Future<List<AcademicProgramModel>> getPrograms() async => [
        const AcademicProgramModel(
          programId: 1,
          programCode: 'BSIT',
          programName: 'Information Technology',
        ),
        const AcademicProgramModel(
          programId: 2,
          programCode: 'BSCS',
          programName: 'Computer Science',
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockStaffRepository implements StaffRepository {
  List<StaffModel> staff = [];
  bool shouldThrow = false;
  CreateStaffRequest? lastCreateRequest;
  UpdateStaffRequest? lastUpdateRequest;

  @override
  Future<List<StaffModel>> getAllStaff() async {
    if (shouldThrow) throw Exception('Network error');
    return staff;
  }

  @override
  Future<StaffModel> createStaff(CreateStaffRequest request) async {
    lastCreateRequest = request;
    if (shouldThrow) throw Exception('Failed to create staff');
    final created = StaffModel(
      userId: 'new-id-123',
      firebaseUid: 'fb-uid-123',
      email: request.email,
      role: request.role,
      roleName: request.role == 2
          ? 'Registrar'
          : request.role == 3
              ? 'Teacher'
              : request.role == 6
                  ? 'College Head'
                  : 'Program Head',
      firstname: request.firstname,
      lastname: request.lastname,
      employeeId: request.employeeId,
      programId: request.programId,
      isRegular: request.isRegular,
      isActive: true,
      createdAt: DateTime.now(),
      passwordResetLink: 'https://auth.example.com/reset?token=xyz',
      firebaseSyncWarning: null,
    );
    staff.add(created);
    return created;
  }

  @override
  Future<StaffModel> disableStaff(String id) async {
    if (shouldThrow) throw Exception('Failed to disable staff');
    final index = staff.indexWhere((s) => s.userId == id);
    final current = staff[index];
    final updated = StaffModel(
      userId: current.userId,
      firebaseUid: current.firebaseUid,
      email: current.email,
      role: current.role,
      roleName: current.roleName,
      firstname: current.firstname,
      lastname: current.lastname,
      employeeId: current.employeeId,
      positionId: current.positionId,
      positionName: current.positionName,
      programId: current.programId,
      programCode: current.programCode,
      isRegular: current.isRegular,
      isActive: false,
      createdAt: current.createdAt,
    );
    staff[index] = updated;
    return updated;
  }

  @override
  Future<StaffModel> reactivateStaff(String id) async {
    if (shouldThrow) throw Exception('Failed to reactivate staff');
    final index = staff.indexWhere((s) => s.userId == id);
    final current = staff[index];
    final updated = StaffModel(
      userId: current.userId,
      firebaseUid: current.firebaseUid,
      email: current.email,
      role: current.role,
      roleName: current.roleName,
      firstname: current.firstname,
      lastname: current.lastname,
      employeeId: current.employeeId,
      positionId: current.positionId,
      positionName: current.positionName,
      programId: current.programId,
      programCode: current.programCode,
      isRegular: current.isRegular,
      isActive: true,
      createdAt: current.createdAt,
    );
    staff[index] = updated;
    return updated;
  }

  @override
  Future<StaffModel> updateStaff(String id, UpdateStaffRequest request) async {
    lastUpdateRequest = request;
    if (shouldThrow) throw Exception('Failed to update staff');
    final index = staff.indexWhere((s) => s.userId == id);
    final current = staff[index];
    final updated = StaffModel(
      userId: current.userId,
      firebaseUid: current.firebaseUid,
      email: current.email,
      role: request.role ?? current.role,
      roleName: (request.role ?? current.role) == 2
          ? 'Registrar'
          : (request.role ?? current.role) == 3
              ? 'Teacher'
              : (request.role ?? current.role) == 6
                  ? 'College Head'
                  : 'Program Head',
      firstname: request.firstname ?? current.firstname,
      lastname: request.lastname ?? current.lastname,
      employeeId: request.employeeId ?? current.employeeId,
      positionId: request.positionId ?? current.positionId,
      positionName: current.positionName,
      programId: (request.role ?? current.role) == 6
          ? null
          : (request.programId ?? current.programId),
      programCode: current.programCode,
      isRegular: request.isRegular ?? current.isRegular,
      isActive: current.isActive,
      createdAt: current.createdAt,
      firebaseSyncWarning: request.role == 2 && current.role == 3
          ? 'Note: This staff member is still assigned as instructor to 1 class(es).'
          : null,
    );
    staff[index] = updated;
    return updated;
  }
}

void main() {
  group('StaffModel & CreateStaffRequest tests', () {
    test('StaffModel parses from json correctly', () {
      final json = {
        'userID': 'user-123',
        'firebaseUID': 'fb-123',
        'email': 'staff@dbtc-cebu.edu.ph',
        'role': 2,
        'roleName': 'Registrar',
        'firstname': 'Maria',
        'lastname': 'Santos',
        'employeeID': 1001,
        'positionID': 'pos-123',
        'positionName': 'Registrar Head',
        'programID': null,
        'programCode': null,
        'isRegular': true,
        'isActive': true,
        'createdAt': '2026-09-11T08:00:00Z',
        'passwordResetLink': 'https://example.com/reset',
        'firebaseSyncWarning': null,
      };

      final model = StaffModel.fromJson(json);
      expect(model.userId, 'user-123');
      expect(model.email, 'staff@dbtc-cebu.edu.ph');
      expect(model.fullName, 'Maria Santos');
      expect(model.role, 2);
      expect(model.roleName, 'Registrar');
      expect(model.employeeId, 1001);
      expect(model.positionName, 'Registrar Head');
      expect(model.isActive, true);
      expect(model.passwordResetLink, 'https://example.com/reset');
    });

    test('CreateStaffRequest serializes to json without PositionID and omits ProgramID when null', () {
      final req = CreateStaffRequest(
        email: 'teacher@dbtc-cebu.edu.ph',
        firstname: 'John',
        lastname: 'Doe',
        role: 3,
        employeeId: 2002,
      );

      final json = req.toJson();
      expect(json['email'], 'teacher@dbtc-cebu.edu.ph');
      expect(json['firstname'], 'John');
      expect(json['lastname'], 'Doe');
      expect(json['role'], 3);
      expect(json['employeeID'], 2002);
      expect(json.containsKey('positionID'), false);
      expect(json.containsKey('programID'), false);
    });

    test('CreateStaffRequest serializes to json with ProgramID when provided', () {
      final req = CreateStaffRequest(
        email: 'head@dbtc-cebu.edu.ph',
        firstname: 'Jane',
        lastname: 'Smith',
        role: 4,
        employeeId: 3003,
        programId: 1,
      );

      final json = req.toJson();
      expect(json['email'], 'head@dbtc-cebu.edu.ph');
      expect(json['firstname'], 'Jane');
      expect(json['lastname'], 'Smith');
      expect(json['role'], 4);
      expect(json['employeeID'], 3003);
      expect(json['programID'], 1);
    });

    test('UpdateStaffRequest serializes to json without email and omits null fields', () {
      final req = UpdateStaffRequest(
        firstname: 'Alex',
        role: 2,
      );

      final json = req.toJson();
      expect(json['firstname'], 'Alex');
      expect(json['role'], 2);
      expect(json.containsKey('email'), false);
      expect(json.containsKey('lastname'), false);
      expect(json.containsKey('employeeID'), false);
      expect(json.containsKey('programID'), false);
    });

    test('UpdateStaffRequest serializes all provided fields', () {
      final req = UpdateStaffRequest(
        firstname: 'Alex',
        lastname: 'Reyes',
        role: 3,
        employeeId: 5005,
        programId: 2,
        isRegular: false,
      );

      final json = req.toJson();
      expect(json['firstname'], 'Alex');
      expect(json['lastname'], 'Reyes');
      expect(json['role'], 3);
      expect(json['employeeID'], 5005);
      expect(json['programID'], 2);
      expect(json['isRegular'], false);
      expect(json.containsKey('email'), false);
    });

    test('CreateStaffRequest strips programId for College Head (role 6) and omits programID in toJson', () {
      final req = CreateStaffRequest(
        email: 'ch@dbtc-cebu.edu.ph',
        firstname: 'College',
        lastname: 'Head',
        role: 6,
        programId: 1, // should be stripped
      );

      expect(req.role, 6);
      expect(req.programId, isNull);
      final json = req.toJson();
      expect(json.containsKey('programID'), false);
      expect(json['role'], 6);
    });

    test('CreateStaffRequest strips programId for Registrar (role 2) and omits programID in toJson', () {
      final req = CreateStaffRequest(
        email: 'reg@dbtc-cebu.edu.ph',
        firstname: 'Reg',
        lastname: 'User',
        role: 2,
        programId: 1, // should be stripped
      );

      expect(req.role, 2);
      expect(req.programId, isNull);
      final json = req.toJson();
      expect(json.containsKey('programID'), false);
      expect(json['role'], 2);
    });

    test('UpdateStaffRequest strips programId for College Head (role 6) and omits programID in toJson', () {
      final req = UpdateStaffRequest(
        firstname: 'College',
        lastname: 'Head',
        role: 6,
        programId: 1, // should be stripped
      );

      expect(req.role, 6);
      expect(req.programId, isNull);
      final json = req.toJson();
      expect(json.containsKey('programID'), false);
      expect(json['role'], 6);
    });
  });

  group('StaffBloc tests', () {
    late MockStaffRepository mockRepo;
    late StaffBloc staffBloc;

    setUp(() {
      mockRepo = MockStaffRepository();
      staffBloc = StaffBloc(mockRepo);
    });

    tearDown(() {
      staffBloc.close();
    });

    test('LoadStaffList loads staff successfully', () async {
      mockRepo.staff = [
        StaffModel(
          userId: 'u1',
          firebaseUid: 'fb1',
          email: 'test@dbtc-cebu.edu.ph',
          role: 2,
          roleName: 'Registrar',
          firstname: 'Test',
          lastname: 'User',
          isRegular: true,
          isActive: true,
          createdAt: DateTime.now(),
        ),
      ];

      staffBloc.add(LoadStaffList());

      await expectLater(
        staffBloc.stream,
        emitsInOrder([
          predicate<StaffState>((s) => s.isLoading == true),
          predicate<StaffState>((s) => s.isLoading == false && s.staffList.length == 1),
        ]),
      );
    });

    test('CreateStaffEvent creates staff and stores createdStaff with reset link', () async {
      final req = CreateStaffRequest(
        email: 'newstaff@dbtc-cebu.edu.ph',
        firstname: 'New',
        lastname: 'Staff',
        role: 4,
      );

      staffBloc.add(CreateStaffEvent(req));

      await expectLater(
        staffBloc.stream,
        emitsInOrder([
          predicate<StaffState>((s) => s.isSubmitting == true),
          predicate<StaffState>((s) =>
              s.isSubmitting == false &&
              s.createdStaff != null &&
              s.createdStaff!.passwordResetLink != null &&
              s.staffList.length == 1),
        ]),
      );
    });

    test('DisableStaffEvent and ReactivateStaffEvent update staff state', () async {
      final initialStaff = StaffModel(
        userId: 'u1',
        firebaseUid: 'fb1',
        email: 'test@dbtc-cebu.edu.ph',
        role: 2,
        roleName: 'Registrar',
        firstname: 'Test',
        lastname: 'User',
        isRegular: true,
        isActive: true,
        createdAt: DateTime.now(),
      );
      mockRepo.staff = [initialStaff];
      staffBloc.add(LoadStaffList());
      await Future.delayed(const Duration(milliseconds: 50));

      staffBloc.add(DisableStaffEvent('u1'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(staffBloc.state.staffList.first.isActive, false);

      staffBloc.add(ReactivateStaffEvent('u1'));
      await Future.delayed(const Duration(milliseconds: 50));
      expect(staffBloc.state.staffList.first.isActive, true);
    });

    test('UpdateStaffEvent updates staff in state and sets warningMessage when present', () async {
      final initialStaff = StaffModel(
        userId: 'u1',
        firebaseUid: 'fb1',
        email: 'teacher@dbtc-cebu.edu.ph',
        role: 3,
        roleName: 'Teacher',
        firstname: 'OldFirst',
        lastname: 'OldLast',
        isRegular: true,
        isActive: true,
        createdAt: DateTime.now(),
      );
      mockRepo.staff = [initialStaff];
      staffBloc.add(LoadStaffList());
      await Future.delayed(const Duration(milliseconds: 50));

      final updateReq = UpdateStaffRequest(
        firstname: 'NewFirst',
        lastname: 'NewLast',
        role: 2,
      );
      staffBloc.add(UpdateStaffEvent('u1', updateReq));
      await Future.delayed(const Duration(milliseconds: 50));

      final updated = staffBloc.state.staffList.first;
      expect(updated.firstname, 'NewFirst');
      expect(updated.lastname, 'NewLast');
      expect(updated.role, 2);
      expect(staffBloc.state.updatedStaff?.firstname, 'NewFirst');
      expect(staffBloc.state.warningMessage, contains('assigned as instructor to 1 class(es)'));
    });

    test('UpdateStaffEvent sets errorMessage on failure', () async {
      final initialStaff = StaffModel(
        userId: 'u1',
        firebaseUid: 'fb1',
        email: 'teacher@dbtc-cebu.edu.ph',
        role: 3,
        roleName: 'Teacher',
        firstname: 'OldFirst',
        lastname: 'OldLast',
        isRegular: true,
        isActive: true,
        createdAt: DateTime.now(),
      );
      mockRepo.staff = [initialStaff];
      mockRepo.shouldThrow = true;

      staffBloc.add(UpdateStaffEvent('u1', UpdateStaffRequest(firstname: 'Fail')));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(staffBloc.state.errorMessage, isNotNull);
      expect(staffBloc.state.isSubmitting, false);
    });

    test('CreateStaffEvent with College Head (role 6) creates staff with roleName College Head', () async {
      mockRepo.staff = [];
      mockRepo.shouldThrow = false;

      final req = CreateStaffRequest(
        email: 'ch@dbtc-cebu.edu.ph',
        firstname: 'College',
        lastname: 'Head',
        role: 6,
        programId: null,
      );

      staffBloc.add(CreateStaffEvent(req));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(staffBloc.state.staffList.length, 1);
      final created = staffBloc.state.staffList.first;
      expect(created.role, 6);
      expect(created.roleName, 'College Head');
      expect(created.programId, isNull);
    });

    test('UpdateStaffEvent to College Head (role 6) updates role and roleName', () async {
      final initialStaff = StaffModel(
        userId: 'u1',
        firebaseUid: 'fb1',
        email: 'ph@dbtc-cebu.edu.ph',
        role: 4,
        roleName: 'Program Head',
        firstname: 'Prog',
        lastname: 'Head',
        programId: 1,
        isRegular: true,
        isActive: true,
        createdAt: DateTime.now(),
      );
      mockRepo.staff = [initialStaff];
      mockRepo.shouldThrow = false;

      staffBloc.add(LoadStaffList());
      await Future.delayed(const Duration(milliseconds: 50));

      final updateReq = UpdateStaffRequest(
        role: 6,
        programId: null,
      );
      staffBloc.add(UpdateStaffEvent('u1', updateReq));
      await Future.delayed(const Duration(milliseconds: 50));

      final updated = staffBloc.state.staffList.first;
      expect(updated.role, 6);
      expect(updated.roleName, 'College Head');
      expect(updated.programId, isNull);
    });
  });

  group('MainLayoutView role check for Staff Management', () {
    test('Staff Management is visible for Admin role', () {
      final navItems = MainLayoutView.buildNavItems(
        role: 1,
        roleName: 'Admin',
      );

      expect(navItems.any((i) => i['title'] == 'Staff Management'), true);
    });

    test('Staff Management is hidden for Registrar role', () {
      final navItems = MainLayoutView.buildNavItems(
        role: 2,
        roleName: 'Registrar',
      );

      expect(navItems.any((i) => i['title'] == 'Staff Management'), false);
    });
  });

  group('StaffManagementView Widget Tests - Role & Academic Program Picker', () {
    late MockStaffRepository mockRepo;
    late StaffBloc staffBloc;

    setUp(() {
      mockRepo = MockStaffRepository();
      staffBloc = StaffBloc(mockRepo);
      if (getIt.isRegistered<AcademicSetupRepository>()) {
        getIt.unregister<AcademicSetupRepository>();
      }
      getIt.registerSingleton<AcademicSetupRepository>(FakeAcademicSetupRepository());
    });

    tearDown(() {
      staffBloc.close();
      if (getIt.isRegistered<AcademicSetupRepository>()) {
        getIt.unregister<AcademicSetupRepository>();
      }
    });

    Widget buildTestWidget() {
      return MaterialApp(
        home: BlocProvider<StaffBloc>.value(
          value: staffBloc,
          child: const StaffManagementView(),
        ),
      );
    }

    testWidgets('Create Dialog: checks picker visibility, requirement per role, and College Head submission without program', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open Add Staff dialog
      await tester.tap(find.text('Add Staff'));
      await tester.pumpAndSettle();

      // 1. Role 2: Registrar (default) -> picker hidden and not required
      expect(find.text('Academic Program *'), findsNothing);
      expect(find.text('Academic Program (Optional)'), findsNothing);

      // 2. Role 3: Teacher -> picker visible and optional
      await tester.tap(find.byKey(const ValueKey('add_staff_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, 'Teacher').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Academic Program (Optional)'), findsOneWidget);
      expect(find.text('Academic Program *'), findsNothing);

      // 3. Role 4: Program Head -> picker visible and required
      await tester.tap(find.byKey(const ValueKey('add_staff_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, 'Program Head').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Academic Program *'), findsOneWidget);

      // Fill in text fields
      await tester.enterText(find.byKey(const ValueKey('staff_email_field')), 'collegehead@dbtc-cebu.edu.ph');
      await tester.enterText(find.byKey(const ValueKey('staff_first_name_field')), 'Maria');
      await tester.enterText(find.byKey(const ValueKey('staff_last_name_field')), 'Santos');
      await tester.pumpAndSettle();

      // Try submitting without program as Program Head -> validation fails
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Academic program is required for Program Head'), findsOneWidget);
      expect(mockRepo.lastCreateRequest, isNull);

      // 4. Role 6: College Head -> picker hidden, not required, and submittable without program
      await tester.tap(find.byKey(const ValueKey('add_staff_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, 'College Head').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Academic Program *'), findsNothing);
      expect(find.text('Academic Program (Optional)'), findsNothing);
      expect(find.text('Academic program is required for Program Head'), findsNothing);

      // Submit College Head
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      // Verify request payload
      expect(mockRepo.lastCreateRequest, isNotNull);
      expect(mockRepo.lastCreateRequest!.role, 6);
      expect(mockRepo.lastCreateRequest!.programId, isNull);

      final payload = mockRepo.lastCreateRequest!.toJson();
      expect(payload.containsKey('programID'), false);
      expect(payload['role'], 6);
      expect(payload['email'], 'collegehead@dbtc-cebu.edu.ph');
      expect(payload['firstname'], 'Maria');
      expect(payload['lastname'], 'Santos');

      // Print payload for output requirement
      debugPrint('Create College Head Request Payload: $payload');
    });

    testWidgets('Create Dialog: switching from Program Head to College Head clears program, and switching back requires it', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Open Add Staff dialog
      await tester.tap(find.text('Add Staff'));
      await tester.pumpAndSettle();

      // Switch to Program Head
      await tester.tap(find.byKey(const ValueKey('add_staff_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, 'Program Head').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Select program BSIT
      await tester.tap(find.byKey(const ValueKey('program_dropdown_4')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BSIT - Information Technology').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('BSIT - Information Technology'), findsOneWidget);

      // Switch to College Head (role 6)
      await tester.tap(find.byKey(const ValueKey('add_staff_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, 'College Head').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Picker is hidden
      expect(find.text('Academic Program *'), findsNothing);
      expect(find.text('BSIT - Information Technology'), findsNothing);

      // Switch back to Program Head (role 4)
      await tester.tap(find.byKey(const ValueKey('add_staff_role_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, 'Program Head').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Picker is visible again and program was cleared
      expect(find.text('Academic Program *'), findsOneWidget);

      // Fill in text fields
      await tester.enterText(find.byKey(const ValueKey('staff_email_field')), 'proghead@dbtc-cebu.edu.ph');
      await tester.enterText(find.byKey(const ValueKey('staff_first_name_field')), 'John');
      await tester.enterText(find.byKey(const ValueKey('staff_last_name_field')), 'Doe');
      await tester.pumpAndSettle();

      // Attempt to submit -> should fail because program was cleared
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Academic program is required for Program Head'), findsOneWidget);
      expect(mockRepo.lastCreateRequest, isNull);
    });

    testWidgets('Edit Dialog: changing role to College Head hides picker and does not send stale programID', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final staffMember = StaffModel(
        userId: 'u-ph-1',
        firebaseUid: 'fb-ph-1',
        email: 'ph@dbtc-cebu.edu.ph',
        role: 4,
        roleName: 'Program Head',
        firstname: 'Alan',
        lastname: 'Turing',
        programId: 1,
        programCode: 'BSIT',
        isRegular: true,
        isActive: true,
        createdAt: DateTime.now(),
      );
      mockRepo.staff = [staffMember];

      await tester.pumpWidget(buildTestWidget());
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      // Open Edit dialog
      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      // Currently Program Head with program picker visible
      expect(find.text('Academic Program *'), findsOneWidget);

      // Change role to College Head (6)
      await tester.tap(find.byKey(ValueKey('edit_role_${staffMember.userId}')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownMenuItem<int>, 'College Head').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Picker is hidden
      expect(find.text('Academic Program *'), findsNothing);
      expect(find.text('Academic Program (Optional)'), findsNothing);

      // Save changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify update request payload
      expect(mockRepo.lastUpdateRequest, isNotNull);
      expect(mockRepo.lastUpdateRequest!.role, 6);
      expect(mockRepo.lastUpdateRequest!.programId, isNull);

      final payload = mockRepo.lastUpdateRequest!.toJson();
      expect(payload.containsKey('programID'), false);
      expect(payload['role'], 6);
      expect(payload['firstname'], 'Alan');
      expect(payload['lastname'], 'Turing');

      debugPrint('Edit College Head Request Payload: $payload');
    });
  });
}
