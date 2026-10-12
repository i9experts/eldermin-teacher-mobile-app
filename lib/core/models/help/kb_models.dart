import '../json_helpers.dart';

/// Knowledge-base article (eldermin-backend `src/modules/knowledge-base/schemas/kb-article.schema.ts`, branch feat/staff-portal 265fcfa): GLOBAL
/// platform content (no tenant filter, service :5), fields module, tabKey, title, tagline, `body` ("Markdown or plain text prose", schema :32-34),
/// `steps` (string list), order. The body is rendered by `parseRichText` (markdown-lite, HTML flattened, images never fetched, links confirmed).
class KbArticle {
  final String module;
  final String tabKey;
  final String title;
  final String tagline;
  final String body;
  final List<String> steps;
  final int order;

  const KbArticle({required this.module, required this.tabKey, required this.title, this.tagline = '', this.body = '', this.steps = const [], this.order = 0});

  static KbArticle? tryParse(Map<String, dynamic> j) {
    final m = readString(j['module']), t = readString(j['tabKey']), title = readString(j['title']);
    if (m == null || t == null || title == null) return null;
    return KbArticle(module: m, tabKey: t, title: title, tagline: readText(j['tagline']), body: readText(j['body']), steps: readStringList(j['steps']), order: readInt(j['order']) ?? 0);
  }

  String get key => '$module/$tabKey';
}

List<KbArticle> parseKbArticles(List<Map<String, dynamic>> rows) => [
      for (final r in rows) ...[
        if (KbArticle.tryParse(r) case final a?) a,
      ],
    ];

/// Display name of a module key: the seeded content is `hr` = "Staff & HR"; any other key is title-cased.
String kbModuleLabel(String module) {
  if (module == 'hr') return 'Staff & HR';
  final words = module.replaceAll(RegExp(r'[_-]+'), ' ').trim().split(' ').where((w) => w.isNotEmpty);
  return words.isEmpty ? module : words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}

/// Which knowledge-base articles the TEACHER app shows. The KB is global platform content and today holds only Staff & HR administration
/// guides (module `hr`: payroll, recruitment, contracts, settings ...), which a teacher must not be shown as "help". There is no
/// teacher-oriented content on the server yet, so the rule is client-side and explicit (nothing is invented):
///  * ALLOW: the module key (lower-cased, `-` / space as `_`) is one of [kHelpAllowedModules];
///  * DENY (wins over allow): any word of the module key or the tab key is in [kHelpDeniedWords] (HR / payroll / finance / admin terms).
/// An article with an unknown module is therefore hidden until the owner adds it to the allow-list (or the backend serves teacher content).
const kHelpAllowedModules = {'general', 'faq', 'getting_started', 'teacher', 'teaching', 'classroom', 'account', 'app'};
const kHelpDeniedWords = {
  'hr', 'payroll', 'payslip', 'payslips', 'salary', 'salaries', 'finance', 'fee', 'fees', 'admin', 'administration', 'recruitment', 'contract', 'contracts',
  'grievance', 'expense', 'expenses', 'settings', 'roles', 'admission', 'admissions', 'onboarding', 'lifecycle', 'exit', 'performance',
};

bool isTeacherHelpArticle(String module, String tabKey) {
  final m = module.trim().toLowerCase().replaceAll(RegExp(r'[-\s]+'), '_');
  if (!kHelpAllowedModules.contains(m)) return false;
  final words = '$m $tabKey'.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty);
  return !words.any(kHelpDeniedWords.contains);
}

List<KbArticle> teacherHelpArticles(Iterable<KbArticle> all) => [for (final a in all) if (isTeacherHelpArticle(a.module, a.tabKey)) a];
