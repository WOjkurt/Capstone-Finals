import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/models/grading_models.dart';
import 'package:sis_teacher_app/views/widgets/student_grade_history_dialog.dart';

GradeModel row(String code, {String? term, double? units, double? finalGrade}) =>
    GradeModel(
      gradeId: 'g-$code',
      studyLoadId: 'sl-$code',
      subjectCode: code,
      termLabel: term,
      units: units,
      finalGrade: finalGrade,
    );

void main() {
  group('GradeModel', () {
    test('parses units and termLabel from the history endpoint', () {
      final g = GradeModel.fromJson(const {
        'gradeID': 'g1',
        'studyLoadID': 'sl1',
        'subjectCode': 'IT 311',
        'units': 3,
        'termLabel': '2026-2027 (1st Sem)',
      });

      expect(g.units, 3.0);
      expect(g.termLabel, '2026-2027 (1st Sem)');
    });

    test('leaves them null when the class sheet omits them', () {
      final g = GradeModel.fromJson(const {
        'gradeID': 'g1',
        'studyLoadID': 'sl1',
      });

      expect(g.units, isNull);
      expect(g.termLabel, isNull);
    });
  });

  group('StudentGradeTerm.group', () {
    test('groups by term, keeping the order the API returned', () {
      final terms = StudentGradeTerm.group([
        row('IT 311', term: '2026-2027 (1st Sem)'),
        row('IT 312', term: '2026-2027 (1st Sem)'),
        row('IT 211', term: '2025-2026 (2nd Sem)'),
      ]);

      expect(terms.map((t) => t.termLabel),
          ['2026-2027 (1st Sem)', '2025-2026 (2nd Sem)']);
      expect(terms.first.grades.map((g) => g.subjectCode), ['IT 311', 'IT 312']);
      expect(terms.last.grades.single.subjectCode, 'IT 211');
    });

    test('sums the units in each term', () {
      final terms = StudentGradeTerm.group([
        row('IT 311', term: 'T1', units: 3),
        row('IT 312', term: 'T1', units: 1.5),
        row('IT 211', term: 'T2', units: 3),
      ]);

      expect(terms.first.totalUnits, 4.5);
      expect(terms.last.totalUnits, 3);
    });

    test('rows with no term collect into one group at the end', () {
      final terms = StudentGradeTerm.group([
        row('OLD 1'),
        row('IT 311', term: 'T1'),
        row('OLD 2', term: ''),
      ]);

      expect(terms.map((t) => t.termLabel), ['T1', 'Other']);
      expect(terms.last.grades.map((g) => g.subjectCode), ['OLD 1', 'OLD 2']);
    });

    test('an empty history groups to nothing', () {
      expect(StudentGradeTerm.group([]), isEmpty);
    });

    test('units missing on a row count as zero, not as a crash', () {
      final terms = StudentGradeTerm.group([
        row('IT 311', term: 'T1', units: 3),
        row('IT 312', term: 'T1'),
      ]);

      expect(terms.single.totalUnits, 3);
    });
  });
}
