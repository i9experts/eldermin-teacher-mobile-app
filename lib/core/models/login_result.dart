import 'institution.dart';
import 'json_helpers.dart';
import 'teacher_user.dart';

/// Response of `POST /auth/login`. Only [accessToken] and the role are
/// trusted here; the full identity comes from `GET /staff-portal/me`.
class LoginResult {
  final String accessToken;
  final TeacherUser user;
  final Institution institution;

  const LoginResult({required this.accessToken, required this.user, required this.institution});

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        accessToken: readString(json['accessToken']) ?? '',
        user: TeacherUser.fromJson(asJsonMap(json['user'])),
        institution: Institution.fromJson(asJsonMap(json['institution'])),
      );
}
