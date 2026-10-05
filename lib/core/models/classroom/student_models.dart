import '../json_helpers.dart';

/// WHITELISTED roster row of `GET /students` (students.service.ts:515-623,
/// fields of student.schema.ts:79-241).
///
/// The real payload also carries, per student: `monthlyTuitionFee` (STS:617-620),
/// guardians with phone/CNIC/email/income (SCH:11-24), address/contact, national
/// ids, medical incl. insurance, transport, scholarship flags ... NONE of that is
/// parsed here: the parser reads exactly the keys below and keeps nothing else
/// (a teacher-facing list must never hold finance or contact data; backlog item 6).
class StudentSummary {
  /// Mongo `_id` (used in routes and attendance writes).
  final String id;
  /// Display id `STU-2026-1234` (SCH:81).
  final String studentId;
  final String firstName;
  final String lastName;
  final String? preferredName;
  final String? gender;
  final String? photoUrl;
  /// Raw stored strings: matching to a class goes through the normaliser.
  final String grade;
  final String section;
  final String? rollNumber;
  /// School register number (SCH:103).
  final String? grNo;
  final String status;
  final String? academicYear;

  const StudentSummary({
    required this.id,
    this.studentId = '',
    this.firstName = '',
    this.lastName = '',
    this.preferredName,
    this.gender,
    this.photoUrl,
    this.grade = '',
    this.section = '',
    this.rollNumber,
    this.grNo,
    this.status = 'active',
    this.academicYear,
  });

  factory StudentSummary.fromJson(Map<String, dynamic> j) => StudentSummary(
        id: readId(j['_id'] ?? j['id']) ?? '',
        studentId: readText(j['studentId']),
        firstName: readText(j['firstName']),
        lastName: readText(j['lastName']),
        preferredName: readString(j['preferredName']),
        gender: readString(j['gender']),
        photoUrl: readString(j['photo']),
        grade: readText(j['currentGrade']),
        section: readText(j['currentSection']),
        rollNumber: readString(j['currentRollNumber']),
        grNo: readString(j['grNo']),
        status: readString(j['status']) ?? 'active',
        academicYear: readString(j['currentAcademicYear']),
      );

  String get fullName => [firstName, lastName].where((e) => e.isNotEmpty).join(' ');

  String get initials {
    final a = firstName.isNotEmpty ? firstName[0] : '';
    final b = lastName.isNotEmpty ? lastName[0] : '';
    final s = '$a$b'.toUpperCase();
    return s.isEmpty ? '?' : s;
  }

  String get classLabel => [grade, section].where((e) => e.isNotEmpty).join(' - ');

  bool get isActive => status == 'active';

  /// Numeric roll numbers sort numerically, anything else after them by text.
  static int compareByRoll(StudentSummary a, StudentSummary b) {
    final x = int.tryParse(a.rollNumber ?? ''), y = int.tryParse(b.rollNumber ?? '');
    if (x != null && y != null && x != y) return x.compareTo(y);
    if (x != null && y == null) return -1;
    if (x == null && y != null) return 1;
    return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
  }

  /// Every field held by the model (tests assert no sensitive value appears here).
  Map<String, Object?> toDebugMap() => {
        'id': id, 'studentId': studentId, 'firstName': firstName, 'lastName': lastName,
        'preferredName': preferredName, 'gender': gender, 'photoUrl': photoUrl, 'grade': grade,
        'section': section, 'rollNumber': rollNumber, 'grNo': grNo, 'status': status,
        'academicYear': academicYear,
      };
}

/// `GET /students/filters/grades-sections` -> `{ grades: [], sections: [] }`
/// (students.service.ts:450-462): school-wide distinct RAW strings.
class GradesSections {
  final List<String> grades;
  final List<String> sections;
  const GradesSections({this.grades = const [], this.sections = const []});

  factory GradesSections.fromJson(Map<String, dynamic> j) =>
      GradesSections(grades: readStringList(j['grades']), sections: readStringList(j['sections']));
}
