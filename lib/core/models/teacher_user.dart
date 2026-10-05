import 'json_helpers.dart';

/// The signed-in staff user. Built from the `user` object of
/// `POST /auth/login` or `GET /staff-portal/me`.
///
/// [staffId] / [teacherProfileId] are NEVER read from JWT claims: callers
/// must merge them in from `GET /staff-portal/me` (see [copyWith]); tokens
/// issued before Phase 1 do not carry them.
class TeacherUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  /// Present only when a school-defined custom role is assigned; then it
  /// fully overrides the standard role matrix (mirrors the web).
  final List<String>? permissions;

  final String? campusId;
  final String? department;
  final String? staffId;
  final String? teacherProfileId;

  const TeacherUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.permissions,
    this.campusId,
    this.department,
    this.staffId,
    this.teacherProfileId,
  });

  factory TeacherUser.fromJson(Map<String, dynamic> json) {
    final perms = json['permissions'];
    return TeacherUser(
      id: readId(json['id'] ?? json['_id']) ?? '',
      name: readString(json['name']) ?? '',
      email: readString(json['email']) ?? '',
      role: readString(json['role']) ?? '',
      avatarUrl: readString(json['avatarUrl']),
      permissions: perms is List ? readStringList(perms) : null,
      campusId: readId(json['campusId']),
      department: readString(json['department']),
      staffId: readString(json['staffId']),
      teacherProfileId: readString(json['teacherProfileId']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatarUrl': avatarUrl,
        if (permissions != null) 'permissions': permissions,
        'campusId': campusId,
        'department': department,
        'staffId': staffId,
        'teacherProfileId': teacherProfileId,
      };

  TeacherUser copyWith({
    String? name,
    String? avatarUrl,
    List<String>? permissions,
    String? campusId,
    String? department,
    String? staffId,
    String? teacherProfileId,
  }) =>
      TeacherUser(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        permissions: permissions ?? this.permissions,
        campusId: campusId ?? this.campusId,
        department: department ?? this.department,
        staffId: staffId ?? this.staffId,
        teacherProfileId: teacherProfileId ?? this.teacherProfileId,
      );

  /// Two-letter initials for the app-bar avatar placeholder.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '--';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
