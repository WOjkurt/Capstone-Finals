import 'package:flutter_test/flutter_test.dart';
import 'package:sis_registrar_app/models/grading_models.dart';
import 'package:sis_registrar_app/models/record_models.dart';

StudentGradeModel _g(String code, double units, double fin, {int load = 1}) =>
    StudentGradeModel(gradeId: code, subjectCode: code, units: units, finalGrade: fin, remarks: fin > 3 ? 2 : 1, loadStatus: load);

void main() {
  test('GWA is weighted by units and counts failed grades', () {
    expect(computeGwa([_g('IT 101', 3, 1.5), _g('IT 102', 1, 3.5)]), 2.0);
    expect(computeGwa([_g('IT 101', 3, 2.0), _g('IT 102', 3, 5.0)]), 3.5);
  });

  test('NSTP, PE/PATHFIT, dropped loads and ungraded subjects are left out', () {
    expect(
      computeGwa([
        _g('IT 101', 3, 2.0),
        _g('NSTP 201A', 3, 1.0),
        _g('PATHFIT 1', 2, 1.0),
        _g('PE 101A', 2, 1.0),
        _g('PE101', 2, 1.0),
        _g('IT 103', 3, 5.0, load: 2),
        const StudentGradeModel(gradeId: 'x', subjectCode: 'IT 104', units: 3),
      ]),
      2.0,
    );
    expect(countsInGwa('PED 101'), isTrue); // not PE
    expect(countsInGwa('nstp 1'), isFalse);
    expect(computeGwa([_g('NSTP 1', 3, 1.0)]), isNull);
  });
}
