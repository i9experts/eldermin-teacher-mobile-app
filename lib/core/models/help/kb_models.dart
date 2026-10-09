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
