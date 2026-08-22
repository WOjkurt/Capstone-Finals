enum UserRole { admin, registrar, teacher, departmentHead, student }
enum ApplicationStatus { pending, approved, rejected }
enum StudentType { newStudent, transferee, old }
enum StudentStatus { enrolled, unenrolled, dropped, graduated }
enum LoadStatus { enrolled, dropped, withdrawn }
enum CorrectionStatus { pendingRegistrar, approved, rejected }
enum RequisiteType { prerequisite, coRequisite }
enum GradeRemark { passed, failed, incomplete, dropped, withdrawn }

extension UserRoleCode on UserRole { int get code => index + 1; String get label => ['Admin', 'Registrar', 'Teacher', 'Department Head', 'Student'][index]; }
extension ApplicationStatusCode on ApplicationStatus { int get code => index + 1; String get label => ['Pending', 'Approved', 'Rejected'][index]; }
extension StudentTypeCode on StudentType { int get code => index + 1; }
extension StudentStatusCode on StudentStatus { int get code => index + 1; String get label => ['Enrolled', 'Unenrolled', 'Dropped', 'Graduated'][index]; }
extension LoadStatusCode on LoadStatus { int get code => index + 1; }
extension CorrectionStatusCode on CorrectionStatus { int get code => index + 1; }
extension RequisiteTypeCode on RequisiteType { int get code => index + 1; }
extension GradeRemarkCode on GradeRemark { int get code => index + 1; String get label => ['Passed', 'Failed', 'Incomplete', 'Dropped', 'Withdrawn'][index]; }
