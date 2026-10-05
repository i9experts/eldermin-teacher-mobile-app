import 'json_helpers.dart';

/// `GET /auth/me` - the backend returns the user document itself (flat,
/// not wrapped). Only what the session check needs is parsed here; the
/// full identity always comes from `GET /staff-portal/me`.
class AuthMe {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? avatarUrl;

  const AuthMe({required this.id, required this.name, required this.email, required this.role, this.avatarUrl});

  factory AuthMe.fromJson(Map<String, dynamic> json) {
    // Tolerate a wrapped `{ user: {...} }` shape like the web's `data.user ?? data`.
    final raw = json['user'] is Map ? asJsonMap(json['user']) : json;
    final profile = asJsonMap(raw['profile']);
    return AuthMe(
      id: readId(raw['id'] ?? raw['_id']) ?? '',
      name: readString(raw['name']) ?? '',
      email: readString(raw['email']) ?? '',
      role: readString(raw['primaryRole'] ?? raw['role']) ?? '',
      avatarUrl: readString(raw['avatarUrl'] ?? profile['avatarUrl']),
    );
  }
}
