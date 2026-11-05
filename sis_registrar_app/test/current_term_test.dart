import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/injection.dart';
import 'package:sis_registrar_app/models/setup_models.dart';
import 'package:sis_registrar_app/repositories/enrollment_repository.dart';
import 'package:sis_registrar_app/services/current_term.dart';

class FakeSetupRepo implements AcademicSetupRepository {
  List<Map<String, Object>> terms;
  FakeSetupRepo(this.terms);
  @override
  Future<List<AcademicTermModel>> getTerms() async => terms.map(AcademicTermModel.fromJson).toList();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const active = {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true};
  const second = {'termID': 't2', 'schoolYear': '2026-2027', 'semester': 2, 'isActive': false};

  test('deleting the chosen term moves to the active term; other terms keep the choice', () async {
    await getIt.reset();
    final repo = FakeSetupRepo([active, second]);
    getIt.registerSingleton<AcademicSetupRepository>(repo);
    final term = CurrentTerm();

    await term.load();
    term.select('t2');

    repo.terms = [active];
    await term.load();                 // already loaded: nothing changes
    expect(term.terms, hasLength(2));

    await term.load(force: true);      // what Setup and the refresh button do
    expect(term.terms, hasLength(1));
    expect(term.termId, 't1');

    repo.terms = [active, second];
    term.select('t1');
    await term.load(force: true);
    expect((term.terms.length, term.termId), (2, 't1'));
    await getIt.reset();
  });
}
