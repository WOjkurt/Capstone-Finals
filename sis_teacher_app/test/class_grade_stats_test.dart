import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/models/grading_models.dart';
import 'package:sis_teacher_app/views/widgets/class_grade_summary.dart';

GradeModel grade({
  String name = 'Dela Cruz, Ana',
  double? midterm,
  double? finalGrade,
}) =>
    GradeModel(
      gradeId: 'g-$name-$midterm-$finalGrade',
      studyLoadId: 'sl-1',
      studentName: name,
      midtermGrade: midterm,
      finalGrade: finalGrade,
    );

void main() {
  group('ClassGradeStats', () {
    test('counts passed, failed and ungraded', () {
      final stats = ClassGradeStats.from([
        grade(name: 'A', midterm: 1.5, finalGrade: 1.75),
        grade(name: 'B', midterm: 2.0, finalGrade: 3.00),
        grade(name: 'C', midterm: 2.5, finalGrade: 4.00),
        grade(name: 'D', midterm: 2.0),
      ]);

      expect(stats.passed, 2); // 3.00 passes
      expect(stats.failed, 1);
      expect(stats.ungraded, 1);
      expect(stats.total, 4);
    });

    test('3.00 passes and 3.1 fails, matching the server rule', () {
      expect(ClassGradeStats.from([grade(finalGrade: 3.00)]).passed, 1);
      expect(ClassGradeStats.from([grade(finalGrade: 3.1)]).failed, 1);
    });

    test('averages only the submitted final grades', () {
      final stats = ClassGradeStats.from([
        grade(name: 'A', finalGrade: 2.00),
        grade(name: 'B', finalGrade: 3.00),
        grade(name: 'C', midterm: 1.0), // no final: excluded
      ]);

      expect(stats.average, 2.5);
      expect(stats.averageLabel, '2.50');
    });

    test('average is null when nothing has a final grade', () {
      final stats = ClassGradeStats.from([grade(midterm: 1.5), grade()]);

      expect(stats.average, isNull);
      expect(stats.averageLabel, '—');
    });

    test('at risk covers failures and failing midterms with no final', () {
      final stats = ClassGradeStats.from([
        grade(name: 'Passed', finalGrade: 2.0),
        grade(name: 'Failed', finalGrade: 5.0),
        grade(name: 'Slipping', midterm: 4.0),
        grade(name: 'Fine so far', midterm: 2.0),
        grade(name: 'Recovered', midterm: 4.0, finalGrade: 2.5),
      ]);

      expect(
        stats.atRisk.map((g) => g.studentName),
        ['Failed', 'Slipping'],
      );
    });

    test('an empty class reports nothing rather than zeroes dividing', () {
      final stats = ClassGradeStats.from([]);

      expect(stats.total, 0);
      expect(stats.average, isNull);
      expect(stats.atRisk, isEmpty);
    });
  });
}
