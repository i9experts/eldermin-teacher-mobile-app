// Safe rendering helpers for server-supplied rich text (circular / event bodies are HTML, KB bodies are markdown or plain text).
//
// RULE: nothing from the server is ever rendered as HTML / run as script / fetched as an image. HTML is reduced to plain text with
// paragraph breaks and bullets; markdown is reduced to a few block kinds; links are surfaced as data and opened only after the
// user confirms (https/http only).

final _scriptStyle = RegExp(r'<(script|style|iframe|object|embed|svg|template)\b[^>]*>[\s\S]*?</\1\s*>', caseSensitive: false);
final _openNoClose = RegExp(r'<(script|style|iframe|object|embed|svg|template)\b[^>]*>', caseSensitive: false);
final _comment = RegExp(r'<!--[\s\S]*?-->');
final _brTag = RegExp(r'<br\s*/?>', caseSensitive: false);
final _blockClose = RegExp(r'</(p|div|h[1-6]|tr|table|ul|ol|blockquote|section|article)\s*>', caseSensitive: false);
final _liOpen = RegExp(r'<li\b[^>]*>', caseSensitive: false);
final _liClose = RegExp(r'</li\s*>', caseSensitive: false);
final _anyTag = RegExp(r'<[^>]*>');

/// True when [s] contains something that looks like an HTML tag.
bool looksLikeHtml(String s) => RegExp(r'<\/?[a-zA-Z][^>]*>').hasMatch(s);

/// HTML -> plain text. Scripts, styles, frames, comments and every other tag disappear (their text content stays except for the dangerous
/// containers above); `<br>`, block ends and `<li>` become line breaks / "• ". Entities are decoded. The result never contains '<' from a tag.
String htmlToPlainText(String html) {
  var s = html.replaceAll(_comment, '');
  s = s.replaceAll(_scriptStyle, '');
  s = s.replaceAll(_openNoClose, ''); // an unclosed <script ...> is dropped too (its tail text stays as inert text)
  s = s.replaceAll(_brTag, '\n').replaceAll(_blockClose, '\n').replaceAll(_liClose, '\n').replaceAll(_liOpen, '• ');
  s = s.replaceAll(_anyTag, '');
  s = decodeEntities(s);
  // A leftover '<' that started a broken tag ("<img src=x onerror=...") is neutralised: no tag can survive as markup because we never parse
  // markup at render time, but strip a dangling opener so the text is clean.
  s = s.replaceAll(RegExp(r'<[a-zA-Z/!][^\n]*$', multiLine: true), '');
  s = s.replaceAll(RegExp(r'[ \t ]+'), ' ').replaceAll(RegExp(r' *\n *'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|[a-zA-Z]+);');
const _named = {'amp': '&', 'lt': '<', 'gt': '>', 'quot': '"', 'apos': "'", 'nbsp': ' ', 'ndash': '-', 'mdash': '-', 'hellip': '...', 'rsquo': "'", 'lsquo': "'", 'rdquo': '"', 'ldquo': '"', 'bull': '•'};

String decodeEntities(String s) => s.replaceAllMapped(_entity, (m) {
      final e = m.group(1)!;
      if (e.startsWith('#x')) {
        final c = int.tryParse(e.substring(2), radix: 16);
        return c == null || c > 0x10FFFF ? m.group(0)! : String.fromCharCode(c);
      }
      if (e.startsWith('#')) {
        final c = int.tryParse(e.substring(1));
        return c == null || c > 0x10FFFF ? m.group(0)! : String.fromCharCode(c);
      }
      return _named[e] ?? m.group(0)!;
    });

/// Only absolute http(s) URLs with a host may ever be opened.
Uri? safeExternalUri(String? raw) {
  if (raw == null) return null;
  final u = Uri.tryParse(raw.trim());
  if (u == null || !u.hasAuthority || u.host.isEmpty) return null;
  final scheme = u.scheme.toLowerCase();
  return scheme == 'https' || scheme == 'http' ? u : null;
}

/// All `href` values of anchors in [html] (https/http only), in order, for a "Links" list. Never opened without confirmation.
List<String> htmlLinks(String html) {
  final out = <String>[];
  for (final m in RegExp(r'''<a\b[^>]*\bhref\s*=\s*["']([^"']+)["']''', caseSensitive: false).allMatches(html)) {
    final u = safeExternalUri(decodeEntities(m.group(1)!));
    if (u != null && !out.contains(u.toString())) out.add(u.toString());
  }
  return out;
}

enum TextBlockKind { heading, paragraph, bullet, numbered }

class InlineRun {
  final String text;
  final String? link; // validated http(s) URL or null
  const InlineRun(this.text, [this.link]);
}

class TextBlock {
  final TextBlockKind kind;
  final List<InlineRun> runs;
  final int? number;
  const TextBlock(this.kind, this.runs, {this.number});
  String get plain => runs.map((r) => r.text).join();
}

final _mdLink = RegExp(r'\[([^\]]+)\]\(([^)\s]+)\)');

List<InlineRun> _inline(String line) {
  final runs = <InlineRun>[];
  var last = 0;
  String clean(String t) => t.replaceAll(RegExp(r'(\*\*|__)'), '').replaceAll(RegExp(r'(?<![\w*])[*_`]|[*_`](?![\w*])'), '');
  for (final m in _mdLink.allMatches(line)) {
    if (m.start > last) runs.add(InlineRun(clean(line.substring(last, m.start))));
    final u = safeExternalUri(m.group(2));
    runs.add(InlineRun(clean(m.group(1)!), u?.toString())); // an unsafe scheme (javascript:, file: ...) keeps the text, drops the link
    last = m.end;
  }
  if (last < line.length) runs.add(InlineRun(clean(line.substring(last))));
  return runs.where((r) => r.text.isNotEmpty).toList();
}

/// Markdown-lite or plain text -> blocks. HTML (if the server sent any) is flattened first. Images (`![alt](url)`) are never fetched: only
/// the alt text remains. Supported: `#` headings, `-`/`*`/`•` bullets, `1.` numbers, paragraphs, `[text](url)` links, `**bold**` (marker dropped).
List<TextBlock> parseRichText(String raw) {
  var s = raw;
  if (looksLikeHtml(s)) s = htmlToPlainText(s);
  s = s.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1');
  final blocks = <TextBlock>[];
  final para = <String>[];
  void flush() {
    if (para.isEmpty) return;
    blocks.add(TextBlock(TextBlockKind.paragraph, _inline(para.join(' '))));
    para.clear();
  }

  for (final rawLine in s.split('\n')) {
    final line = rawLine.trimRight();
    final t = line.trim();
    if (t.isEmpty) {
      flush();
      continue;
    }
    final h = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(t);
    final b = RegExp(r'^[-*•]\s+(.*)$').firstMatch(t);
    final n = RegExp(r'^(\d{1,3})[.)]\s+(.*)$').firstMatch(t);
    if (h != null) {
      flush();
      blocks.add(TextBlock(TextBlockKind.heading, _inline(h.group(1)!)));
    } else if (b != null) {
      flush();
      blocks.add(TextBlock(TextBlockKind.bullet, _inline(b.group(1)!)));
    } else if (n != null) {
      flush();
      blocks.add(TextBlock(TextBlockKind.numbered, _inline(n.group(2)!), number: int.parse(n.group(1)!)));
    } else {
      para.add(t);
    }
  }
  flush();
  return blocks;
}
