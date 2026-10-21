import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/design/design.dart';
import '../../core/utils/safe_text.dart';
import 'external_link.dart';

/// Renders [raw] (markdown-lite / plain text / flattened HTML, see [parseRichText]) as selectable-free, inert text: headings, bullets, numbers,
/// paragraphs. Links are tappable but open only after the confirmation dialog of [ExternalLinks]. No images, no HTML, no scripts.
class RichTextView extends StatefulWidget {
  final String raw;
  const RichTextView(this.raw, {super.key});

  @override
  State<RichTextView> createState() => _RichTextViewState();
}

class _RichTextViewState extends State<RichTextView> {
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  TextSpan _span(List<InlineRun> runs, TextStyle base) {
    return TextSpan(style: base, children: [
      for (final r in runs)
        if (r.link == null)
          TextSpan(text: r.text)
        else
          TextSpan(
            text: r.text,
            style: const TextStyle(color: EmColors.primary, decoration: TextDecoration.underline),
            recognizer: (TapGestureRecognizer()..onTap = () => ExternalLinks.openWithConfirm(r.link)),
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    final blocks = parseRichText(widget.raw);
    final base = EmType.body.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400, height: 1.5);
    return Column(key: const Key('rich_text'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final b in blocks)
        Padding(
          padding: EdgeInsets.only(bottom: EmSpacing.s8, top: b.kind == TextBlockKind.heading ? EmSpacing.s8 : 0),
          child: switch (b.kind) {
            TextBlockKind.heading => Text.rich(_span(b.runs, EmType.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: EmColors.ink, height: 1.5))),
            TextBlockKind.paragraph => Text.rich(_span(b.runs, base)),
            TextBlockKind.bullet => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('•  ', style: base), Expanded(child: Text.rich(_span(b.runs, base)))]),
            TextBlockKind.numbered => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: EmSpacing.s32, child: Text('${b.number}.', style: base.copyWith(fontWeight: FontWeight.w700))), Expanded(child: Text.rich(_span(b.runs, base)))]),
          },
        ),
    ]);
  }
}
