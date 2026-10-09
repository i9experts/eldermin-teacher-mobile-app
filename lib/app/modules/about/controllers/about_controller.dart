import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../../core/constants/api_constants.dart';

class AppInfo {
  final String name;
  final String version;
  final String build;
  const AppInfo(this.name, this.version, this.build);
}

/// About (`/about`): app name, version and build (package_info_plus) and the API HOST only (never the full URL, never a token or any debug value).
class AboutController extends GetxController {
  final Future<AppInfo> Function() _loader;
  AboutController({Future<AppInfo> Function()? loader}) : _loader = loader ?? _fromPlatform;

  static Future<AppInfo> _fromPlatform() async {
    final p = await PackageInfo.fromPlatform();
    return AppInfo(p.appName, p.version, p.buildNumber);
  }

  /// Host of the server the app talks to, e.g. `api.eldermin.com`.
  static String get apiHost => hostOf(ApiConstants.baseUrl);

  static String hostOf(String url) {
    final u = Uri.tryParse(url);
    if (u == null || u.host.isEmpty) return '';
    return u.hasPort && u.port != 0 && !(u.scheme == 'https' && u.port == 443) && !(u.scheme == 'http' && u.port == 80) ? '${u.host}:${u.port}' : u.host;
  }

  final info = Rxn<AppInfo>();
  final failed = false.obs;

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    try {
      info.value = await _loader();
      failed.value = false;
    } catch (_) {
      failed.value = true;
    }
  }
}
