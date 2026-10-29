import 'json_helpers.dart';

/// One (grade, section, subject) the teacher is assigned to.
class TeachingAssignment {
  final String? sectionId;
  final String? sectionName;
  final String? subjectName;
  final String? gradeLevel;
  final int? periodsPerWeek;

  const TeachingAssignment({
    this.sectionId,
    this.sectionName,
    this.subjectName,
    this.gradeLevel,
    this.periodsPerWeek,
  });

  factory TeachingAssignment.fromJson(Map<String, dynamic> json) => TeachingAssignment(
        sectionId: readId(json['sectionId']),
        sectionName: readString(json['sectionName']),
        subjectName: readString(json['subjectName']),
        gradeLevel: readString(json['gradeLevel']),
        periodsPerWeek: readInt(json['periodsPerWeek']),
      );

  Map<String, dynamic> toJson() => {
        'sectionId': sectionId,
        'sectionName': sectionName,
        'subjectName': subjectName,
        'gradeLevel': gradeLevel,
        'periodsPerWeek': periodsPerWeek,
      };
}

/// The grade/section a class teacher is responsible for.
class ClassTeacherInfo {
  final String? gradeId;
  final String? gradeName;
  final String? sectionName;
  final String? label;

  const ClassTeacherInfo({this.gradeId, this.gradeName, this.sectionName, this.label});

  factory ClassTeacherInfo.fromJson(Map<String, dynamic> json) => ClassTeacherInfo(
        gradeId: readString(json['gradeId']),
        gradeName: readString(json['gradeName']),
        sectionName: readString(json['sectionName']),
        label: readString(json['label']) ?? readString(json['name']), // `name` on classTeacherAssignments[]
      );

  Map<String, dynamic> toJson() => {
        'gradeId': gradeId,
        'gradeName': gradeName,
        'sectionName': sectionName,
        'label': label,
      };

  String get displayName =>
      label ?? [gradeName, sectionName].where((e) => e != null && e.isNotEmpty).join(' - ');
}

/// `teacherProfile` of `GET /staff-portal/me`.
class TeacherProfile {
  final String? employeeId;
  final String? designation;
  final String? department;
  final String? photoUrl;
  final List<String> subjectsCanTeach;
  final List<String> gradeLevelsCanTeach;
  final List<TeachingAssignment> currentAssignments;
  final String? status;
  final bool isClassTeacher;
  /// The first class-teacher assignment only (backend keeps it for old clients).
  final ClassTeacherInfo? classTeacherOf;

  /// EVERY class-teacher assignment (staff-portal.service.ts `classTeacherAssignments`); falls back to
  /// `[classTeacherOf]` when the array is missing/empty (an older backend).
  final List<ClassTeacherInfo> classTeacherAssignments;

  const TeacherProfile({
    this.employeeId,
    this.designation,
    this.department,
    this.photoUrl,
    this.subjectsCanTeach = const [],
    this.gradeLevelsCanTeach = const [],
    this.currentAssignments = const [],
    this.status,
    this.isClassTeacher = false,
    this.classTeacherOf,
    this.classTeacherAssignments = const [],
  });

  factory TeacherProfile.fromJson(Map<String, dynamic> json) {
    final ct = json['classTeacherOf'];
    final first = ct is Map ? ClassTeacherInfo.fromJson(asJsonMap(ct)) : null;
    final all = asJsonMapList(json['classTeacherAssignments']).map(ClassTeacherInfo.fromJson).toList();
    return TeacherProfile(
      employeeId: readString(json['employeeId']),
      designation: readString(json['designation']),
      department: readString(json['department']),
      photoUrl: readString(json['photoUrl']),
      subjectsCanTeach: readStringList(json['subjectsCanTeach']),
      gradeLevelsCanTeach: readStringList(json['gradeLevelsCanTeach']),
      currentAssignments:
          asJsonMapList(json['currentAssignments']).map(TeachingAssignment.fromJson).toList(),
      status: readString(json['status']),
      isClassTeacher: readBool(json['isClassTeacher']),
      classTeacherOf: first,
      classTeacherAssignments: all.isNotEmpty ? all : [if (first != null) first],
    );
  }

  Map<String, dynamic> toJson() => {
        'employeeId': employeeId,
        'designation': designation,
        'department': department,
        'photoUrl': photoUrl,
        'subjectsCanTeach': subjectsCanTeach,
        'gradeLevelsCanTeach': gradeLevelsCanTeach,
        'currentAssignments': currentAssignments.map((a) => a.toJson()).toList(),
        'status': status,
        'isClassTeacher': isClassTeacher,
        'classTeacherOf': classTeacherOf?.toJson(),
        'classTeacherAssignments': classTeacherAssignments.map((a) => a.toJson()).toList(),
      };
}
