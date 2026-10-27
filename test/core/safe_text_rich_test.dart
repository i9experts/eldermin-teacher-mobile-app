// Ported from eldermin-parent-mobile-app test/core/utils/safe_text_test.dart (fixtures = the web consent editor's HTML) — keep in sync.
import 'package:eldermin_teacher_app/core/utils/safe_text.dart';
import 'package:flutter_test/flutter_test.dart';

// Fixtures use the HTML the web consent editor produces (Eldermin-Frontend src/pages/school-calendar/RichTextEditor.tsx: a contentEditable
// div driven by document.execCommand — Chrome emits <b>/<i>/<u>, one <div> per Enter, <div><br></div> for an empty line, <ul>/<ol><li>,
// <a href> from createLink, <img src> from insertImage, &nbsp; for runs of spaces), plus hostile / unsupported markup.
const editorOutput = 'Dear parents,<div>We are taking <b>Class 5</b> to the <i>museum</i> on <u>12&nbsp;Nov</u> &amp; back.</div>'
    '<div><br></div><div>Please send:</div>'
    '<ul><li>Packed lunch</li><li>Water bottle<ul><li>1 litre</li></ul></li></ul>'
    '<ol><li>Sign the slip</li><li>Return by Friday</li></ol>'
    '<div>Details: <a href="https://school.edu/trip?id=1&amp;x=2">trip page</a>&nbsp;or <a href="mailto:office@school.edu">email us</a> or <a href="tel:+9200000">call</a></div>'
    '<div>Permission slip:</div><div><img src="https://cdn.school.edu/consent-attachments/slip.png"></div>';

String text(List<TextBlock> b) => b.map((x) => x.plain).join('\n');

void main() {
  group('editor output', () {
    final blocks = parseRichText(editorOutput);

    test('each Enter (div) is its own paragraph, empty paragraph is only a gap', () {
      expect(blocks.first.plain, 'Dear parents,');
      expect(blocks[1].plain, 'We are taking Class 5 to the museum on 12 Nov & back.');
      expect(blocks[2].plain, 'Please send:');
      expect(blocks[1].kind, TextBlockKind.paragraph);
    });

    test('bold / italic / underline degrade to readable plain text', () {
      expect(blocks[1].plain, contains('Class 5'));
      expect(blocks[1].plain, isNot(contains('<')));
    });

    test('bulleted, nested and numbered lists', () {
      final lists = blocks.where((b) => b.kind != TextBlockKind.paragraph).toList();
      expect(lists.map((b) => '${b.kind.name}:${b.plain}').toList(), [
        'bullet:Packed lunch',
        'bullet:Water bottle',
        'bullet:1 litre',
        'numbered:Sign the slip',
        'numbered:Return by Friday',
      ]);
      expect(lists.where((b) => b.kind == TextBlockKind.numbered).map((b) => b.number).toList(), [1, 2]);
    });

    test('links keep their URL (http, https, mailto, tel); &amp; in the href is decoded', () {
      final links = [for (final b in blocks) for (final r in b.runs) if (r.link != null) r];
      expect(links.map((r) => r.text).toList(), ['trip page', 'email us', 'call', 'Image']);
      expect(links[0].link, 'https://school.edu/trip?id=1&x=2');
      expect(links[1].link, 'mailto:office@school.edu');
      expect(links[2].link, 'tel:+9200000');
    });

    test('an inline image becomes a tappable "Image" link, never fetched', () {
      expect(blocks.last.runs.single.text, 'Image');
      expect(blocks.last.runs.single.link, 'https://cdn.school.edu/consent-attachments/slip.png');
    });

    test('no raw tag text on screen', () {
      expect(text(blocks), isNot(matches(RegExp(r'</?[a-zA-Z][^>]*>'))));
    });
  });

  group('entities and breaks', () {
    test('&amp; &nbsp; &lt;', () {
      expect(text(parseRichText('<div>Tom &amp; Jerry&nbsp;&nbsp;now</div>')), 'Tom & Jerry now');
      expect(text(parseRichText('<div>1 &lt; 2</div>')), '1 < 2');
    });
    test('<br> breaks a line inside one block', () {
      final b = parseRichText('<div>line one<br>line two</div>');
      expect(b.map((x) => x.plain).toList(), ['line one', 'line two']);
    });
    test('several empty paragraphs never produce empty blocks', () {
      final b = parseRichText('<div>a</div><div><br></div><div><br></div><div><br></div><div>b</div>');
      expect(b.map((x) => x.plain).toList(), ['a', 'b']);
    });
    test('plain text and markdown-lite still join consecutive lines', () {
      expect(parseRichText('one\ntwo').single.plain, 'one two');
      expect(parseRichText('# Title\n- a\n1. b').map((b) => b.kind).toList(), [TextBlockKind.heading, TextBlockKind.bullet, TextBlockKind.numbered]);
    });
  });

  group('headings and tables', () {
    test('h1-h6 become headings', () {
      final b = parseRichText('<h2>Trip</h2><p>Body</p>');
      expect(b.first.kind, TextBlockKind.heading);
      expect(b.first.plain, 'Trip');
      expect(b[1].kind, TextBlockKind.paragraph);
    });
    test('a table degrades to readable rows (cells separated, rows on their own line)', () {
      final b = parseRichText('<table><tr><th>Item</th><th>Cost</th></tr><tr><td>Bus</td><td>Rs 500</td></tr></table>');
      expect(b.map((x) => x.plain).toList(), ['Item Cost', 'Bus Rs 500']);
    });
  });

  group('hostile markup', () {
    test('script and iframe content never renders', () {
      final t = text(parseRichText('Hi<script>alert("x")</script><iframe src="https://evil.example">frame text</iframe> there'));
      expect(t, 'Hi there');
      expect(t, isNot(contains('alert')));
      expect(t, isNot(contains('frame text')));
    });
    test('an unclosed script / iframe drops its tail', () {
      expect(text(parseRichText('<div>keep</div><script>alert(1)')), 'keep');
      expect(text(parseRichText('<div>keep</div><iframe src=x>secret')), 'keep');
    });
    test('style, comment, svg, object, embed content is dropped', () {
      final t = text(parseRichText('a<style>.x{color:red}</style><!-- c --><svg><text>svg</text></svg><object>o</object><embed src=x>b'));
      expect(t, 'ab');
    });
    test('img with an event handler and a broken tag leave no markup', () {
      final t = text(parseRichText('<div>ok<img src=x onerror=alert(1)></div><div><b onclick="x">bold</b> <img src="javascript:alert(1)" alt="pic"></div>'));
      expect(t, isNot(contains('onerror')));
      expect(t, isNot(contains('<')));
      expect(t, contains('bold'));
      expect(t, contains('pic'));
    });
    test('javascript: / file: / data: links keep the text, drop the link', () {
      final b = parseRichText('<a href="javascript:alert(1)">click</a> <a href="file:///etc/passwd">f</a> <a href="data:text/html,x">d</a>');
      expect([for (final x in b) for (final r in x.runs) r.link], everyElement(isNull));
      expect(text(b), 'click f d');
    });
    test('markdown-style javascript link in plain text is not a link either', () {
      expect(parseRichText('[x](javascript:alert(1))').single.runs.single.link, isNull);
    });
    test('an escaped tag typed by the admin stays inert text', () {
      expect(text(parseRichText('<div>&lt;b&gt;not bold&lt;/b&gt;</div>')), '<b>not bold</b>');
    });
  });

  group('link schemes', () {
    test('safeLinkUri (rich-text links) allows http, https, mailto, tel only', () {
      expect(safeLinkUri('https://a.example/x'), isNotNull);
      expect(safeLinkUri('http://a.example'), isNotNull);
      expect(safeLinkUri('mailto:a@b.co'), isNotNull);
      expect(safeLinkUri('tel:+123'), isNotNull);
      for (final bad in ['javascript:alert(1)', 'file:///x', 'data:text/html,x', 'ftp://a.example', 'intent://x', 'https://', 'mailto:', '//a.example', '/relative', '', null]) {
        expect(safeLinkUri(bad), isNull, reason: '$bad');
      }
    });
    test('safeExternalUri (attachments, everything else) stays http(s) only', () {
      expect(safeExternalUri('mailto:a@b.co'), isNull);
      expect(safeExternalUri('tel:+123'), isNull);
      expect(safeExternalUri('https://a.example'), isNotNull);
    });
  });

  group('htmlToPlainText (calendar bodies) keeps its plain-text contract', () {
    test('no link / image / heading markers, unchanged list and break output', () {
      expect(htmlToPlainText('See <a href="https://x.test/p">the page</a> <img src="https://x.test/a.png" alt="pic"><h2>Head</h2>'), 'See the page Head');
      expect(htmlToPlainText('<ul><li>One</li><li>Two</li></ul>'), '• One\n• Two');
    });
    test('safety: an unclosed script / iframe drops its tail', () {
      expect(htmlToPlainText('keep<script>alert(1)'), 'keep');
      expect(htmlToPlainText('keep<iframe src=x>secret'), 'keep');
      expect(htmlToPlainText('a<embed src=x>b'), 'ab');
    });
  });
}
