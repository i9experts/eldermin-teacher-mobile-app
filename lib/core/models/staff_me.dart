import 'institution.dart';
import 'json_helpers.dart';
import 'teacher_profile.dart';
import 'teacher_user.dart';

class CampusRef {
  final String id;
  final String? name;
  const CampusRef({required this.id, this.name});

  factory CampusRef.fromJson(Map<String, dynamic> json) =>
      CampusRef(id: readId(json['id']) ?? '', name: readString(json['name']));

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}

/// Typed shape of `GET /api/v1/staff-portal/me`
/// (eldermin-backend `staff-portal.service.ts` `getMe`).
///
/// This response - never the JWT - is the only source of [staffId] and
/// [teacherProfileId].
class StaffMe {
  final TeacherUser user; // staffId / teacherProfileId already merged in
  final String staffId;
  final String? teacherProfileId;
  final TeacherProfile? teacherProfile;
  final String? department;
  final CampusRef? campus;
  final Institution institution;

  const StaffMe({
    required this.user,
    required this.staffId,
    this.teacherProfileId,
    this.teacherProfile,
    this.department,
    this.campus,
    required this.institution,
  });

  factory StaffMe.fromJson(Map<String, dynamic> json) {
    final staffId = readString(json['staffId']) ?? '';
    final teacherProfileId = readString(json['teacherProfileId']);
    final department = readString(json['department']);
    final campus = json['campus'];
    final tp = json['teacherProfile'];
    final user = TeacherUser.fromJson(asJsonMap(json['user'])).copyWith(
      staffId: staffId,
      teacherProfileId: teacherProfileId,
      department: department,
      campusId: campus is Map ? readId(campus['id']) : null,
    );
    return StaffMe(
      user: user,
      staffId: staffId,
      teacherProfileId: teacherProfileId,
      teacherProfile: tp is Map ? TeacherProfile.fromJson(asJsonMap(tp)) : null,
      department: department,
      campus: campus is Map ? CampusRef.fromJson(asJsonMap(campus)) : null,
      institution: Institution.fromJson(asJsonMap(json['institution'])),
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'staffId': staffId,
        'teacherProfileId': teacherProfileId,
        'teacherProfile': teacherProfile?.toJson(),
        'department': department,
        'campus': campus?.toJson(),
        'institution': institution.toJson(),
      };

  bool get isClassTeacher => teacherProfile?.isClassTeacher ?? false;

  /// "Campus - Department" subtitle for the app bar (either part may be absent).
  String get subtitle =>
      [campus?.name, department].where((e) => e != null && e.isNotEmpty).join(' · ');
}
