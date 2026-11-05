import 'package:flutter_test/flutter_test.dart';
import 'package:sis_student_app/models/class_models.dart';

void main() {
  group('ClassScheduleModel tests', () {
    test('deserializes from JSON and formats time and summary correctly', () {
      final json = {
        'scheduleID': 'sched-1',
        'classID': 'class-1',
        'daysOfWeek': 'MWF',
        'startTime': '08:00:00',
        'endTime': '09:30:00',
        'room': 'CS Lab 1',
      };

      final schedule = ClassScheduleModel.fromJson(json);

      expect(schedule.scheduleId, 'sched-1');
      expect(schedule.classId, 'class-1');
      expect(schedule.daysOfWeek, 'MWF');
      expect(schedule.room, 'CS Lab 1');
      expect(schedule.formattedTime, '8:00 AM – 9:30 AM');
      expect(schedule.summary, 'MWF 8:00 AM – 9:30 AM · CS Lab 1');
    });

    test('handles afternoon/evening times properly in 12-hour format', () {
      final json = {
        'scheduleID': 'sched-2',
        'classID': 'class-1',
        'daysOfWeek': 'TTh',
        'startTime': '13:30:00',
        'endTime': '15:00:00',
        'room': 'Room 402',
      };

      final schedule = ClassScheduleModel.fromJson(json);

      expect(schedule.formattedTime, '1:30 PM – 3:00 PM');
      expect(schedule.summary, 'TTh 1:30 PM – 3:00 PM · Room 402');
    });
  });

  group('ClassModel tests', () {
    test('deserializes from JSON with embedded schedules', () {
      final json = {
        'classID': 'class-101',
        'subjectID': 'sub-202',
        'subjectCode': 'IT 311',
        'subjectTitle': 'Systems Integration and Architecture',
        'userID': 'teacher-1',
        'teacherName': 'Prof. Rizal',
        'termID': 'term-1',
        'termSchoolYear': '2024-2025',
        'termSemester': 1,
        'className': 'BSIT-3A',
        'createdAt': '2026-09-01T08:00:00Z',
        'schedules': [
          {
            'scheduleID': 's-1',
            'classID': 'class-101',
            'daysOfWeek': 'MWF',
            'startTime': '08:00:00',
            'endTime': '09:30:00',
            'room': 'Lab 1',
          },
          {
            'scheduleID': 's-2',
            'classID': 'class-101',
            'daysOfWeek': 'Sat',
            'startTime': '10:00:00',
            'endTime': '12:00:00',
            'room': 'Room 101',
          }
        ],
      };

      final classModel = ClassModel.fromJson(json);

      expect(classModel.classId, 'class-101');
      expect(classModel.subjectCode, 'IT 311');
      expect(classModel.subjectTitle, 'Systems Integration and Architecture');
      expect(classModel.className, 'BSIT-3A');
      expect(classModel.teacherName, 'Prof. Rizal');
      expect(classModel.termLabel, '2024-2025 (1st Sem)');
      expect(classModel.enrolledCount, 0);
      expect(classModel.schedules.length, 2);
      expect(classModel.scheduleSummary,
          'MWF 8:00 AM – 9:30 AM · Lab 1 | Sat 10:00 AM – 12:00 PM · Room 101');
    });

    test('handles empty schedules and null semester gracefully', () {
      final json = {
        'classID': 'class-empty',
        'subjectID': 'sub-1',
        'className': 'BSIT-1B',
        'termID': 'term-2',
        'termSchoolYear': '2025-2026',
        'schedules': <dynamic>[],
      };

      final classModel = ClassModel.fromJson(json);

      expect(classModel.schedules, isEmpty);
      expect(classModel.scheduleSummary, 'No schedule assigned');
      expect(classModel.termLabel, '2025-2026');
    });

    test('deserializes enrolledCount correctly when provided', () {
      final json = {
        'classID': 'class-enrolled',
        'subjectID': 'sub-1',
        'className': 'BSIT-2A',
        'termID': 'term-1',
        'enrolledCount': 42,
      };

      final classModel = ClassModel.fromJson(json);

      expect(classModel.enrolledCount, 42);
    });
  });

  group('ClassRosterItemModel tests', () {
    test('deserializes StudyLoadResponseDto shape including StudentUserId and StudentName', () {
      final json = {
        'studyLoadId': 'sl-1',
        'studentUserId': 'user-student-1',
        'studentName': 'Kurt Wojtyle Rizal',
        'subjectCode': 'IT 311',
        'subjectTitle': 'Systems Integration',
        'className': 'BSIT-3A',
        'teacherName': 'Prof. Smith',
        'loadStatus': 'Enrolled',
        'termLabel': '2024-2025 (Sem 1)',
      };

      final rosterItem = ClassRosterItemModel.fromJson(json);

      expect(rosterItem.studyLoadId, 'sl-1');
      expect(rosterItem.studentUserId, 'user-student-1');
      expect(rosterItem.studentName, 'Kurt Wojtyle Rizal');
      expect(rosterItem.displayName, 'Kurt Wojtyle Rizal');
      expect(rosterItem.loadStatus, 'Enrolled');
    });

    test('falls back to Unknown Student when name is missing or empty', () {
      final json = {
        'studyLoadId': 'sl-2',
        'studentUserId': 'user-2',
        'studentName': null,
        'subjectCode': 'IT 101',
        'subjectTitle': 'Intro',
        'className': 'BSIT-1A',
        'loadStatus': 'Active',
        'termLabel': '2024-2025',
      };

      final rosterItem = ClassRosterItemModel.fromJson(json);

      expect(rosterItem.studentName, isNull);
      expect(rosterItem.displayName, 'Unknown Student');
    });
  });
}
