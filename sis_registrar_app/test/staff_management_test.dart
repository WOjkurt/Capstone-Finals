import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/staff_model.dart';
import 'package:sis_registrar_app/blocs/staff_bloc.dart';
import 'package:sis_registrar_app/repositories/staff_repository.dart';
import 'package:sis_registrar_app/views/main_layout_view.dart';

class MockStaffRepository implements StaffRepository {
  List<StaffModel> staff = [];
  bool shouldThrow = false;

  @override
  Future<List<StaffModel>> getAllStaff() async {
    if (shouldThrow) throw Exception('Network error');
    return staff;
  }

  @override
  Future<StaffModel> createStaff(CreateStaffRequest request) async {
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
}
