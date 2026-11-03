import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/models/grading_models.dart';
import 'package:sis_teacher_app/repositories/grading_repository.dart';
import 'package:sis_teacher_app/services/auth_service.dart';

class FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserSearchResultModel _user(String id, String last, int role) => UserSearchResultModel(
      userId: id,
      firstname: 'F',
      lastname: last,
      email: '$id@dbtc-cebu.edu.ph',
      role: role,
    );

/// Returns different people per role, and records each call.
class RoleFakeUserSearchRepository extends UserSearchRepository {
  final calls = <(String?, int?)>[];
  RoleFakeUserSearchRepository() : super(FakeAuthService());

  @override
  Future<List<UserSearchResultModel>> search({String? query, int? role}) async {
    calls.add((query, role));
    if (role == 3) return [_user('t1', 'Zamora', 3), _user('dup', 'Cruz', 3)];
    if (role == 4) return [_user('ph1', 'Abad', 4), _user('dup', 'Cruz', 4)];
    return [];
  }
}

void main() {
  test('searchTeachingStaff asks for Teachers (3) and Program Heads (4) with the same query', () async {
    final repo = RoleFakeUserSearchRepository();

    await repo.searchTeachingStaff(query: 'abc');

    expect(repo.calls.toSet(), {('abc', 3), ('abc', 4)});
  });

  test('searchTeachingStaff merges both roles, removes duplicates and sorts by last name', () async {
    final repo = RoleFakeUserSearchRepository();

    final result = await repo.searchTeachingStaff();

    expect(result.map((u) => u.userId), ['ph1', 'dup', 't1']);
    expect(result.first.role, 4);
  });
}
