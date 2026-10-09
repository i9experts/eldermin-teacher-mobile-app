import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/safe_text.dart';
import 'external_link.dart';

/// Renders [raw] (markdown-lite / plain text / flattened HTML, see [parseRichText]) as selectable-free, inert text: headings, bullets, numbers,
/// paragraphs. Links are tappable but open only after the confirmation dialog of [ExternalLinks]. No images, no HTML, no scripts.
class RichTextView extends StatefulWidget {
  final String raw;
  final double fontSize;
  const RichTextView(this.raw, {super.key, this.fontSize = 13.5});

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
            style: const TextStyle(color: AppColors.blue, decoration: TextDecoration.underline),
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
    final base = TextStyle(fontSize: widget.fontSize, color: AppColors.ink, height: 1.5);
    return Column(key: const Key('rich_text'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final b in blocks)
        Padding(
          padding: EdgeInsets.only(bottom: b.kind == TextBlockKind.heading ? 6 : 8, top: b.kind == TextBlockKind.heading ? 6 : 0),
          child: switch (b.kind) {
            TextBlockKind.heading => Text.rich(_span(b.runs, base.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryColor, fontSize: widget.fontSize + 1.5))),
            TextBlockKind.paragraph => Text.rich(_span(b.runs, base)),
            TextBlockKind.bullet => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('•  ', style: base), Expanded(child: Text.rich(_span(b.runs, base)))]),
            TextBlockKind.numbered => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 26, child: Text('${b.number}.', style: base.copyWith(fontWeight: FontWeight.w700))), Expanded(child: Text.rich(_span(b.runs, base)))]),
          },
        ),
    ]);
  }
}
