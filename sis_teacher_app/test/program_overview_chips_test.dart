import 'package:flutter_test/flutter_test.dart';
import 'package:sis_teacher_app/models/class_models.dart';

void main() {
  group('ProgramOverview Quick Filters logic tests', () {
    final class1 = ClassModel(
      classId: 'c1',
      subjectId: 's1',
      subjectCode: 'IT 101',
      subjectTitle: 'Intro to IT',
      yearLevel: 1,
      userId: null, // Unassigned faculty
      teacherName: null,
      termId: 't1',
      className: 'IT-1A',
      enrolledCount: 0, // Zero enrolled
      schedules: const [], // No schedule
    );

    final class2 = ClassModel(
      classId: 'c2',
      subjectId: 's2',
      subjectCode: 'IT 201',
      subjectTitle: 'Data Structures',
      yearLevel: 2,
      userId: 'teacher-1',
      teacherName: 'Prof. Juan',
      termId: 't1',
      className: 'IT-2A',
      enrolledCount: 15,
      schedules: const [
        ClassScheduleModel(
          scheduleId: 'sch-1',
          classId: 'c2',
          daysOfWeek: 'MWF',
          startTime: '08:00:00',
          endTime: '09:00:00',
          room: 'Lab 1',
        ),
      ],
    );

    final class3 = ClassModel(
      classId: 'c3',
      subjectId: 's3',
      subjectCode: 'IT 301',
      subjectTitle: 'Web Development',
      yearLevel: 3,
      userId: null, // Unassigned faculty
      teacherName: null,
      termId: 't1',
      className: 'IT-3A',
      enrolledCount: 20,
      schedules: const [
        ClassScheduleModel(
          scheduleId: 'sch-2',
          classId: 'c3',
          daysOfWeek: 'TTH',
          startTime: '10:00:00',
          endTime: '11:30:00',
          room: 'Lab 2',
        ),
      ],
    );

    final class4 = ClassModel(
      classId: 'c4',
      subjectId: 's4',
      subjectCode: 'IT 401',
      subjectTitle: 'Capstone',
      yearLevel: 4,
      userId: 'teacher-2',
      teacherName: 'Prof. Maria',
      termId: 't1',
      className: 'IT-4A',
      enrolledCount: 0, // Zero enrolled
      schedules: const [], // No schedule
    );

    final List<ClassModel> allClasses = [class1, class2, class3, class4];

    List<ClassModel> applyFilters({
      required List<ClassModel> list,
      int? selectedYearLevel,
      bool filterUnassignedFaculty = false,
      bool filterNoSchedule = false,
      bool filterZeroEnrolled = false,
    }) {
      return list.where((c) {
        if (selectedYearLevel != null && c.yearLevel != selectedYearLevel) {
          return false;
        }
        if (filterUnassignedFaculty && (c.userId != null && c.userId!.isNotEmpty)) {
          return false;
        }
        if (filterNoSchedule && c.schedules.isNotEmpty) {
          return false;
        }
        if (filterZeroEnrolled && c.enrolledCount > 0) {
          return false;
        }
        return true;
      }).toList();
    }

    test('Unfiltered returns all classes', () {
      final result = applyFilters(list: allClasses);
      expect(result.length, 4);
    });

    test('Filter by Unassigned Faculty', () {
      final result = applyFilters(
        list: allClasses,
        filterUnassignedFaculty: true,
      );
      expect(result.map((c) => c.classId).toList(), ['c1', 'c3']);
    });

    test('Filter by No Schedule', () {
      final result = applyFilters(
        list: allClasses,
        filterNoSchedule: true,
      );
      expect(result.map((c) => c.classId).toList(), ['c1', 'c4']);
    });

    test('Filter by Zero Enrolled', () {
      final result = applyFilters(
        list: allClasses,
        filterZeroEnrolled: true,
      );
      expect(result.map((c) => c.classId).toList(), ['c1', 'c4']);
    });

    test('Combine Unassigned Faculty and No Schedule', () {
      final result = applyFilters(
        list: allClasses,
        filterUnassignedFaculty: true,
        filterNoSchedule: true,
      );
      expect(result.map((c) => c.classId).toList(), ['c1']);
    });

    test('Combine Unassigned Faculty and Year Level', () {
      final result = applyFilters(
        list: allClasses,
        selectedYearLevel: 3,
        filterUnassignedFaculty: true,
      );
      expect(result.map((c) => c.classId).toList(), ['c3']);
    });

    test('Combine Zero Enrolled and Assigned Teacher', () {
      final result = applyFilters(
        list: allClasses,
        filterZeroEnrolled: true,
      ).where((c) => c.userId != null).toList();
      expect(result.map((c) => c.classId).toList(), ['c4']);
    });

    test('Combine all quick filters: Unassigned, No Schedule, Zero Enrolled', () {
      final result = applyFilters(
        list: allClasses,
        filterUnassignedFaculty: true,
        filterNoSchedule: true,
        filterZeroEnrolled: true,
      );
      expect(result.map((c) => c.classId).toList(), ['c1']);
    });

    test('Combine all quick filters with non-matching year level', () {
      final result = applyFilters(
        list: allClasses,
        selectedYearLevel: 2,
        filterUnassignedFaculty: true,
        filterNoSchedule: true,
        filterZeroEnrolled: true,
      );
      expect(result.isEmpty, isTrue);
    });
  });
}
