import 'dart:convert';
import 'package:http/http.dart' as http;

/// Unknown requests get an empty list so pages show their empty states.
Future<http.Response> fakeApi(http.Request req) async {
  final path = req.url.path;
  Object body = <Object>[];
  if (path.endsWith('/api/AcademicTerms')) {
    body = [
      {'termID': 't1', 'schoolYear': '2026-2027', 'semester': 1, 'isActive': true},
      {'termID': 't0', 'schoolYear': '2025-2026', 'semester': 2, 'isActive': false},
    ];
  } else if (path.endsWith('/api/AcademicPrograms')) {
    body = [
      {'programID': 1, 'programCode': 'BSIT', 'programName': 'BS Information Technology'},
      {'programID': 2, 'programCode': 'BSME', 'programName': 'BS Mechanical Engineering'},
      {'programID': 3, 'programCode': 'BTVTED', 'programName': 'BTVTEd'},
    ];
  } else if (path.contains('/api/studyloads/pending-summary')) {
    body = [
      {'userId': 'u1', 'fullName': 'Ana Cruz', 'programCode': 'BSIT', 'yearLevel': 1, 'pendingCount': 7, 'pendingUnits': 24, 'termUnits': 24, 'maxUnits': 21, 'isOverloaded': true, 'overloadApprovedBy': 'Carla Head', 'overloadReason': 'Catching up'},
      {'userId': 'u2', 'fullName': 'Ben Santos', 'programCode': 'BSME', 'yearLevel': 2, 'pendingCount': 8, 'pendingUnits': 26, 'termUnits': 26, 'maxUnits': 28},
      {'userId': 'u3', 'fullName': 'Cara Lim', 'programCode': 'BTVTED', 'yearLevel': 1, 'pendingCount': 6, 'pendingUnits': 21, 'termUnits': 21, 'maxUnits': 24},
    ];
  } else if (path.endsWith('/api/GradeCorrections/pending') || path.endsWith('/api/gradecorrections/pending')) {
    body = [
      {'correctionId': 'c1', 'gradeId': 'g1', 'correctionPeriod': 2, 'correctionPeriodLabel': 'Final', 'oldGrade': 1.0, 'newGrade': 3.0, 'reason': 'Encoding error', 'requestedByUserID': 't1', 'requesterName': 'Ben Teach', 'correctionStatus': 1, 'correctionStatusLabel': 'Pending', 'dateRequested': '2026-11-03T02:00:00Z', 'subjectCode': 'IT 101', 'subjectTitle': 'Introduction to Computing', 'studentName': 'Ana Cruz'},
    ];
  } else if (path.endsWith('/api/reports/enrollment-summary')) {
    body = [
      {'programCode': 'BSIT', 'yearLevel': 1, 'enrolledStudents': 42, 'pendingOnlyStudents': 3},
      {'programCode': 'BSIT', 'yearLevel': 2, 'enrolledStudents': 38, 'pendingOnlyStudents': 0},
      {'programCode': 'BSME', 'yearLevel': 1, 'enrolledStudents': 35, 'pendingOnlyStudents': 1},
      {'programCode': 'BTVTED', 'yearLevel': 1, 'enrolledStudents': 27, 'pendingOnlyStudents': 0},
    ];
  } else if (path.endsWith('/api/students/search')) {
    body = [
      {'userId': 'u1', 'firstname': 'Ana', 'lastname': 'Cruz', 'email': 'ana.cruz@dbtc-cebu.edu.ph', 'programId': 1, 'programCode': 'BSIT', 'yearLevel': 1, 'role': 5, 'lrn': '123456789012', 'hasLrn': true},
      {'userId': 'u2', 'firstname': 'Ben', 'lastname': 'Santos', 'email': 'ben.santos@dbtc-cebu.edu.ph', 'programId': 2, 'programCode': 'BSME', 'yearLevel': 2, 'role': 5, 'hasLrn': false},
      {'userId': 'u3', 'firstname': 'Cara', 'lastname': 'Lim', 'email': 'cara.lim@dbtc-cebu.edu.ph', 'programId': 3, 'programCode': 'BTVTED', 'yearLevel': 1, 'role': 5, 'lrn': '987654321098', 'hasLrn': true},
    ];
  } else if (path.startsWith('/api/gradeclearances/')) {
    body = [
      {'clearanceId': 'cl1', 'userId': 'u1', 'termId': 't1', 'termLabel': '2026-2027 (1st Semester)', 'isCleared': false},
      {'clearanceId': 'cl0', 'userId': 'u1', 'termId': 't0', 'termLabel': '2025-2026 (2nd Semester)', 'isCleared': true, 'clearedByUserName': 'Rita Reg', 'clearedAt': '2026-05-30T08:00:00Z'},
    ];
  } else if (path.startsWith('/api/studyloads/student/')) {
    Map<String, dynamic> load(String code, String title, String status, int units, String days, String start, String end, String room) => {
          'studyLoadId': 'sl-$code', 'studentUserId': 'u1', 'studentName': 'Ana Cruz', 'subjectCode': code, 'subjectTitle': title,
          'className': 'BSIT 1A', 'teacherName': 'Ben Teach', 'loadStatus': status, 'termLabel': '2026-2027 (1st Semester)', 'units': units,
          'schedules': [
            {'scheduleId': 's-$code', 'classId': 'c-$code', 'daysOfWeek': days, 'startTime': start, 'endTime': end, 'room': room}
          ],
        };
    body = [
      load('IT 101', 'Introduction to Computing', 'Enrolled', 3, 'M/W/F', '08:00:00', '09:00:00', 'R101'),
      load('IT 102', 'Computer Programming 1', 'Enrolled', 3, 'T/TH', '10:00:00', '11:30:00', 'Lab 2'),
      load('GEC 101', 'Understanding the Self', 'Pending', 3, 'M/W', '13:00:00', '14:30:00', 'R203'),
    ];
  } else if (path.endsWith('/api/studyloads/unit-limit')) {
    body = {'maxUnits': 21, 'currentUnits': 9, 'rule': 'Regular limit is the curriculum load 21 units.'};
  } else if (path.startsWith('/api/grades/student/')) {
    body = [
      {'gradeId': 'g1', 'subjectCode': 'IT 100', 'subjectTitle': 'Computer Basics', 'units': 3, 'midtermGrade': 2.0, 'finalGrade': 1.75, 'remarks': 1, 'termLabel': '2025-2026 (2nd Semester)', 'schoolYear': '2025-2026', 'semester': 2, 'loadStatus': 1, 'teacherName': 'Ben Teach', 'className': 'BSIT 1A'},
      {'gradeId': 'g2', 'subjectCode': 'MATH 100', 'subjectTitle': 'College Algebra', 'units': 3, 'midtermGrade': 3.0, 'finalGrade': 5.0, 'remarks': 2, 'termLabel': '2025-2026 (2nd Semester)', 'schoolYear': '2025-2026', 'semester': 2, 'loadStatus': 1, 'teacherName': 'Dina Santos', 'className': 'BSIT 1A'},
    ];
  } else if (path.startsWith('/api/credited-subjects/student/')) {
    body = [
      {'creditedSubjectId': 'cr1', 'subjectId': 's9', 'subjectCode': 'GEC 102', 'subjectTitle': 'Readings in Philippine History', 'units': 3, 'yearLevel': 1, 'sourceSchool': 'Cebu Technological University', 'grade': '1.5', 'schoolYear': '2024-2025', 'recordedBy': 'Rita Reg'},
    ];
  } else if (path.endsWith('/api/activity-log')) {
    body = {
      'items': [
        {'id': 'a1', 'occurredAt': '2026-11-04T01:20:00Z', 'actorName': 'Carla Head', 'actorRole': 6, 'action': 'LOADS_SAVED', 'studentUserId': 'u1', 'studentName': 'Ana Cruz', 'termLabel': '2026-2027 (1st Semester)', 'summary': 'Saved 3 subject(s) as Pending'},
        {'id': 'a2', 'occurredAt': '2026-11-04T02:05:00Z', 'actorName': 'Rita Reg', 'actorRole': 2, 'action': 'LOADS_FINALIZED', 'studentUserId': 'u1', 'studentName': 'Ana Cruz', 'termLabel': '2026-2027 (1st Semester)', 'summary': 'Finalized 2 subject(s): IT 101, IT 102'},
      ],
      'page': 1,
      'pageSize': 25,
      'totalCount': 2,
    };
  }
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
}
