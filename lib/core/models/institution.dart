import 'json_helpers.dart';

/// The school (tenant) the user belongs to. `activeModules` are the
/// tenant's activated module ids - used as a UI visibility rule only
/// (the backend does not enforce it).
class Institution {
  final String? name;
  final String? slug;
  final String? plan;
  final List<String> activeModules;

  const Institution({this.name, this.slug, this.plan, this.activeModules = const []});

  factory Institution.fromJson(Map<String, dynamic> json) => Institution(
        name: readString(json['name']),
        slug: readString(json['slug']),
        plan: readString(json['plan']),
        activeModules: readStringList(json['activeModules']),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'slug': slug,
        'plan': plan,
        'activeModules': activeModules,
      };

  bool hasModule(String id) => activeModules.contains(id);
}
