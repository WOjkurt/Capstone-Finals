import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sis_student_app/blocs/profile_bloc.dart';
import 'package:sis_student_app/models/class_models.dart';
import 'package:sis_student_app/models/grading_models.dart';
import 'package:sis_student_app/models/setup_models.dart';
import 'package:sis_student_app/models/student_models.dart';
import 'package:sis_student_app/repositories/student_repository.dart';
import 'package:sis_student_app/views/profile_view.dart';

class MockStudentRepository implements StudentRepository {
  StudentProfileModel? profileToReturn;
  bool shouldThrow = false;

  @override
  Future<StudentProfileModel> getMyProfile() async {
    if (shouldThrow) throw Exception('Network error');
    if (profileToReturn == null) throw Exception('No profile configured');
    return profileToReturn!;
  }

  // ── Unused stubs ─────────────────────────────────────────────────────────

  @override
  Future<AcademicTermModel?> getActiveTerm() async => null;

  @override
  Future<List<AcademicTermModel>> getAllTerms() async => [];

  @override
  Future<List<GradeClearanceModel>> getGradeClearances(String userId) async =>
      [];

  @override
  Future<List<GradeModel>> getGrades(String userId, String termId) async => [];

  @override
  Future<List<StudentScheduleItemModel>> getMySchedule(
          String userId, String termId) async =>
      [];
}

// ── Sample data ──────────────────────────────────────────────────────────────

final _fullProfile = StudentProfileModel(
  userDetailId: 'ud-1',
  userId: 'user-1',
  firstname: 'Juan',
  lastname: 'Dela Cruz',
  lrn: '123456789012',
  programId: 1,
  programCode: 'BSIT',
  programName: 'Bachelor of Science in Information Technology',
  studentType: 2,
  studentStatus: 1,
  yearLevel: 1,
  isRegular: true,
);

final _minimalProfile = StudentProfileModel(
  userDetailId: 'ud-2',
  userId: 'user-2',
  firstname: 'Maria',
  lastname: 'Santos',
);

// ── Unit tests ───────────────────────────────────────────────────────────────

void main() {
  group('StudentProfileModel unit tests', () {
    test('fullName concatenates firstname and lastname', () {
      expect(_fullProfile.fullName, 'Juan Dela Cruz');
    });

    test('initials are first letter of first and last name', () {
      expect(_fullProfile.initials, 'JD');
    });

    test('initials fall back to S when both names are empty', () {
      final empty = StudentProfileModel(
        userDetailId: '',
        userId: '',
        firstname: '',
        lastname: '',
      );
      expect(empty.initials, 'S');
    });

    test('yearLevelLabel maps 1 → 1st Year', () {
      expect(_fullProfile.yearLevelLabel, '1st Year');
    });

    test('yearLevelLabel defaults to 1st Year when yearLevel is null', () {
      expect(_minimalProfile.yearLevelLabel, '1st Year');
    });

    test('studentStatusLabel maps 1 → Enrolled', () {
      expect(_fullProfile.studentStatusLabel, 'Enrolled');
    });

    test('studentStatusLabel defaults to Active when status is null', () {
      expect(_minimalProfile.studentStatusLabel, 'Active');
    });

    test('studentTypeLabel maps 2 → Old / Continuing', () {
      expect(_fullProfile.studentTypeLabel, 'Old / Continuing');
    });

    test('regularStatusLabel returns Regular when isRegular is true', () {
      expect(_fullProfile.regularStatusLabel, 'Regular');
    });

    test('regularStatusLabel returns Irregular when isRegular is false', () {
      final irr = StudentProfileModel(
        userDetailId: 'x',
        userId: 'x',
        firstname: 'A',
        lastname: 'B',
        isRegular: false,
      );
      expect(irr.regularStatusLabel, 'Irregular');
    });

    test('programDisplay prefers programCode over programName', () {
      expect(_fullProfile.programDisplay, 'BSIT');
    });

    test('programDisplay falls back to programName when code is absent', () {
      final noCode = StudentProfileModel(
        userDetailId: 'x',
        userId: 'x',
        firstname: 'A',
        lastname: 'B',
        programName: 'BS Computer Science',
      );
      expect(noCode.programDisplay, 'BS Computer Science');
    });

    test('programDisplay falls back to General Curriculum when no program', () {
      expect(_minimalProfile.programDisplay, 'General Curriculum');
    });

    test('fromJson parses all fields correctly', () {
      final json = {
        'userDetailID': 'ud-99',
        'userID': 'u-99',
        'firstname': 'Test',
        'lastname': 'User',
        'lrn': '999000000001',
        'programID': 3,
        'programCode': 'BSCS',
        'programName': 'BS Computer Science',
        'studentType': 1,
        'studentStatus': 1,
        'yearLevel': 2,
        'isRegular': false,
      };
      final m = StudentProfileModel.fromJson(json);
      expect(m.userDetailId, 'ud-99');
      expect(m.firstname, 'Test');
      expect(m.lastname, 'User');
      expect(m.lrn, '999000000001');
      expect(m.programCode, 'BSCS');
      expect(m.yearLevel, 2);
      expect(m.isRegular, false);
    });

    test('fromJson tolerates camelCase variant field names', () {
      final json = {
        'userDetailId': 'ud-x',
        'userId': 'u-x',
        'firstName': 'A',
        'lastName': 'B',
        'LRN': 'lrn-val',
        'programId': 2,
      };
      final m = StudentProfileModel.fromJson(json);
      expect(m.userDetailId, 'ud-x');
      expect(m.firstname, 'A');
      expect(m.lastname, 'B');
      expect(m.lrn, 'lrn-val');
      expect(m.programId, 2);
    });
  });

  // ── Bloc tests ────────────────────────────────────────────────────────────

  group('ProfileBloc tests', () {
    late MockStudentRepository repo;
    late ProfileBloc bloc;

    setUp(() {
      repo = MockStudentRepository();
      bloc = ProfileBloc(repo);
    });

    tearDown(() => bloc.close());

    test('initial state is ProfileInitial', () {
      expect(bloc.state, isA<ProfileInitial>());
    });

    test('emits Loading then Loaded with profile', () async {
      repo.profileToReturn = _fullProfile;
      bloc.add(LoadProfileEvent());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ProfileLoading>(),
          predicate<ProfileLoaded>(
              (s) => s.profile.fullName == 'Juan Dela Cruz'),
        ]),
      );
    });

    test('emits ProfileError when repository throws', () async {
      repo.shouldThrow = true;
      bloc.add(LoadProfileEvent());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ProfileLoading>(),
          isA<ProfileError>(),
        ]),
      );
    });

    test('refresh does not emit Loading when already loaded', () async {
      repo.profileToReturn = _fullProfile;
      bloc.add(LoadProfileEvent());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final states = <ProfileState>[];
      final subscription = bloc.stream.listen(states.add);

      bloc.add(LoadProfileEvent(refresh: true));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      // Should go straight to Loaded without an intermediate Loading
      expect(states.whereType<ProfileLoading>(), isEmpty);
      expect(states.whereType<ProfileLoaded>(), isNotEmpty);
    });
  });

  // ── Widget tests ─────────────────────────────────────────────────────────

  group('ProfileView widget tests', () {
    late MockStudentRepository repo;

    setUp(() {
      repo = MockStudentRepository();
    });

    Widget build(ProfileBloc bloc) {
      return MaterialApp(
        home: BlocProvider<ProfileBloc>.value(
          value: bloc,
          child: const ProfileView(email: 'student@dbtc-cebu.edu.ph'),
        ),
      );
    }

    testWidgets('renders loading indicator initially', (tester) async {
      // Profile loads asynchronously — pump once to get the loading frame
      repo.profileToReturn = _fullProfile;
      final bloc = ProfileBloc(repo);

      await tester.pumpWidget(build(bloc));
      // Only initial pump — data not yet returned
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      bloc.close();
    });

    testWidgets('renders profile details when loaded', (tester) async {
      repo.profileToReturn = _fullProfile;
      final bloc = ProfileBloc(repo);
      bloc.add(LoadProfileEvent());

      await tester.pumpWidget(build(bloc));
      await tester.pump();
      await tester.pumpAndSettle();

      // Identity card
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('JD'), findsOneWidget);
      expect(find.textContaining('LRN:'), findsOneWidget);

      // Academic card
      expect(find.text('BSIT'), findsOneWidget);
      expect(find.text('1st Year'), findsOneWidget);
      expect(find.text('Regular'), findsOneWidget);

      // Account card
      expect(find.text('student@dbtc-cebu.edu.ph'), findsOneWidget);

      bloc.close();
    });

    testWidgets('renders error state with retry button when loading fails',
        (tester) async {
      repo.shouldThrow = true;
      final bloc = ProfileBloc(repo);
      // Don't add the event here — ProfileView.initState fires LoadProfileEvent.
      // Adding it twice before the pump causes a double-throw in the same frame.

      await tester.pumpWidget(build(bloc));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Could Not Load Profile'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      bloc.close();
    });
  });
}
