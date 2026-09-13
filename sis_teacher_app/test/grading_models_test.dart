import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/models/grading_models.dart';

void main() {
  group('GradeModel tests', () {
    test('deserializes complete GradeResponseDto from JSON', () {
      final json = {
        'gradeId': 'g-101',
        'studyLoadId': 'sl-202',
        'midtermGrade': 1.75,
        'finalGrade': 2.00,
        'remarks': 1,
        'remarksLabel': 'Passed',
        'submittedByUserID': 'teacher-1',
        'teacherName': 'Prof. Rizal',
        'dateSubmitted': '2026-09-13T10:00:00Z',
        'studentUserId': 'student-1',
        'studentName': 'Kurt Wojtyle',
        'subjectCode': 'IT 311',
        'subjectTitle': 'Systems Integration',
        'className': 'BSIT-3A',
      };

      final grade = GradeModel.fromJson(json);

      expect(grade.gradeId, 'g-101');
      expect(grade.studyLoadId, 'sl-202');
      expect(grade.midtermGrade, 1.75);
      expect(grade.finalGrade, 2.00);
      expect(grade.remarks, 1);
      expect(grade.remarksLabel, 'Passed');
      expect(grade.submittedByUserID, 'teacher-1');
      expect(grade.teacherName, 'Prof. Rizal');
      expect(grade.studentUserId, 'student-1');
      expect(grade.studentName, 'Kurt Wojtyle');
      expect(grade.subjectCode, 'IT 311');
      expect(grade.subjectTitle, 'Systems Integration');
      expect(grade.className, 'BSIT-3A');
      expect(grade.isMidtermSubmitted, isTrue);
      expect(grade.isFinalSubmitted, isTrue);
    });

    test('handles null grade and remarks fields when student has not been graded', () {
      final json = {
        'gradeId': 'g-102',
        'studyLoadId': 'sl-203',
        'midtermGrade': null,
        'finalGrade': null,
        'remarks': null,
        'remarksLabel': null,
        'submittedByUserID': null,
        'teacherName': null,
        'dateSubmitted': null,
        'studentUserId': 'student-2',
        'studentName': 'Jane Doe',
      };

      final grade = GradeModel.fromJson(json);

      expect(grade.gradeId, 'g-102');
      expect(grade.studyLoadId, 'sl-203');
      expect(grade.midtermGrade, isNull);
      expect(grade.finalGrade, isNull);
      expect(grade.remarks, isNull);
      expect(grade.remarksLabel, isNull);
      expect(grade.isMidtermSubmitted, isFalse);
      expect(grade.isFinalSubmitted, isFalse);
    });

    test('handles midterm-only submitted state correctly', () {
      final json = {
        'gradeId': 'g-103',
        'studyLoadId': 'sl-204',
        'midtermGrade': 1.50,
        'finalGrade': null,
      };

      final grade = GradeModel.fromJson(json);

      expect(grade.isMidtermSubmitted, isTrue);
      expect(grade.isFinalSubmitted, isFalse);
    });
  });

  group('Batch Models tests', () {
    test('serializes SubmitGradeBatchModel to expected backend JSON shape', () {
      const batch = SubmitGradeBatchModel(
        classId: 'class-uuid',
        grades: [
          SubmitGradeBatchItemModel(
            studyLoadId: 'sl-1',
            midtermGrade: 1.25,
            finalGrade: 1.50,
          ),
          SubmitGradeBatchItemModel(
            studyLoadId: 'sl-2',
            midtermGrade: 2.00,
            finalGrade: null,
          ),
        ],
      );

      final json = batch.toJson();

      expect(json['classId'], 'class-uuid');
      final grades = json['grades'] as List;
      expect(grades.length, 2);
      expect(grades[0]['studyLoadId'], 'sl-1');
      expect(grades[0]['midtermGrade'], 1.25);
      expect(grades[0]['finalGrade'], 1.50);
      expect(grades[1]['studyLoadId'], 'sl-2');
      expect(grades[1]['midtermGrade'], 2.00);
      expect(grades[1]['finalGrade'], isNull);
    });

    test('deserializes GradeBatchResultModel with succeeded and failed lists', () {
      final json = {
        'succeeded': [
          {
            'gradeId': 'g-1',
            'studyLoadId': 'sl-1',
            'midtermGrade': 1.75,
            'finalGrade': 2.00,
            'remarks': 1,
            'remarksLabel': 'Passed',
          },
        ],
        'failed': [
          {
            'studyLoadId': 'sl-2',
            'reason': 'Midterm grade has already been submitted and cannot be modified.',
          },
        ],
      };

      final result = GradeBatchResultModel.fromJson(json);

      expect(result.succeeded.length, 1);
      expect(result.succeeded.first.gradeId, 'g-1');
      expect(result.succeeded.first.remarksLabel, 'Passed');

      expect(result.failed.length, 1);
      expect(result.failed.first.studyLoadId, 'sl-2');
      expect(result.failed.first.reason,
          'Midterm grade has already been submitted and cannot be modified.');
    });
  });

  group('Grading Scale Validation tests', () {
    test('isValidGradeValue allows only values from DBTC collegiate scale', () {
      final valid = [1.00, 1.25, 1.50, 1.75, 2.00, 2.25, 2.50, 2.75, 3.00, 5.00];
      for (final val in valid) {
        expect(isValidGradeValue(val), isTrue, reason: '$val should be valid');
      }

      final invalid = [0.0, 1.1, 1.2, 1.3, 2.1, 3.1, 4.0, 5.5, 75.0, 99.0];
      for (final val in invalid) {
        expect(isValidGradeValue(val), isFalse, reason: '$val should be invalid');
      }
    });

    test('validateGradeString allows empty or null input', () {
      expect(validateGradeString(null), isNull);
      expect(validateGradeString(''), isNull);
      expect(validateGradeString('   '), isNull);
    });

    test('validateGradeString rejects non-scale values and non-numeric input', () {
      expect(validateGradeString('1.25'), isNull);
      expect(validateGradeString('3.00'), isNull);
      expect(validateGradeString('5.00'), isNull);

      expect(validateGradeString('1.3'), isNotNull);
      expect(validateGradeString('15'), isNotNull);
      expect(validateGradeString('abc'), isNotNull);
      expect(validateGradeString('4.00'), isNotNull);
    });
  });
}
