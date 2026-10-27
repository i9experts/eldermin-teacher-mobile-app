// Mirrored from eldermin-parent-mobile-app lib/core/widgets/detail_bottom_sheet.dart (fix/list-row-details) — keep in sync.
// The only difference is the attachment opener default (the teacher link helper always asks before opening).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/components/external_link.dart';
import '../../app/components/rich_text_view.dart';
import '../design/design.dart';

/// One label / value row. A null or blank [value] hides the row.
class DetailField {
  const DetailField(this.label, this.value);
  final String label;
  final String? value;
  bool get visible => value != null && value!.trim().isNotEmpty;
}

/// A titled group of [DetailField]s (e.g. "Your response"). Hidden when none of its fields has a value.
class DetailSection {
  const DetailSection(this.title, this.fields);
  final String title;
  final List<DetailField> fields;
}

class DetailAttachment {
  const DetailAttachment(this.name, this.url);
  final String name;
  final String url;
}

enum DetailSheetState { ready, loading, error }

/// Everything a [DetailBottomSheet] shows. Empty values are hidden: fields, sections, long text, attachments and the footer are all optional.
class DetailSheetData {
  const DetailSheetData({
    required this.title,
    this.statusLabel,
    this.statusTone = EmTone.neutral,
    this.notice,
    this.fields = const [],
    this.longText,
    this.longTextLabel,
    this.longTextIsRich = false,
    this.sections = const [],
    this.attachments = const [],
    this.footer,
    this.state = DetailSheetState.ready,
    this.errorMessage,
    this.onRetry,
  });

  final String title;
  final String? statusLabel;
  final EmTone statusTone;

  /// A one-line note under the header (e.g. "This request has expired").
  final String? notice;
  final List<DetailField> fields;

  /// Long body text. [longTextIsRich] renders it through the safe rich-text view (HTML / markdown-lite), otherwise as plain text.
  final String? longText;
  final String? longTextLabel;
  final bool longTextIsRich;
  final List<DetailSection> sections;
  final List<DetailAttachment> attachments;

  /// Pinned below the scrolling content, above the safe area. Null hides it.
  final Widget? footer;

  /// For a sheet that fetches by id: [DetailSheetState.loading] shows a spinner, [DetailSheetState.error] the message with Retry ([onRetry]).
  final DetailSheetState state;
  final String? errorMessage;
  final VoidCallback? onRetry;
}

/// Reusable record-detail sheet on [EmBottomSheet]'s chrome: header (title + status chip), key-value rows, long text, attachments and an
/// optional sticky footer. Draggable (drag the sheet taller / shorter, or down to dismiss), scrolls when the content is long, keeps the footer
/// above the system gesture area and the keyboard.
class DetailBottomSheet extends StatelessWidget {
  const DetailBottomSheet({super.key, required this.data, this.scroll, this.onOpenAttachment});

  final DetailSheetData data;
  final ScrollController? scroll;

  /// Opens an attachment URL. Defaults to [ExternalLinks.openWithConfirm] (http / https only, after a confirmation, outside the app).
  final void Function(String url)? onOpenAttachment;

  /// Shows the sheet. [data] is read on every build, so with [reactive] (wraps the body in an `Obx`) it must read at least one Rx value and the
  /// sheet then updates when that value changes; without it the sheet shows [data] as it is now.
  static Future<T?> show<T>(BuildContext context, {required DetailSheetData Function() data, bool reactive = false, void Function(String url)? onOpenAttachment}) {
    return EmBottomSheet.showPanel<T>(
      context,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => reactive
            ? Obx(() => DetailBottomSheet(data: data(), scroll: scroll, onOpenAttachment: onOpenAttachment))
            : DetailBottomSheet(data: data(), scroll: scroll, onOpenAttachment: onOpenAttachment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(key: const Key('detail_sheet'), children: [
      Expanded(child: _content(context, d)),
      if (d.state == DetailSheetState.ready && d.footer != null)
        DecoratedBox(
          key: const Key('detail_sheet_footer'),
          decoration: const BoxDecoration(color: EmColors.surface, border: Border(top: BorderSide(color: EmColors.border))),
          child: SafeArea(
            top: false,
            child: Padding(padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s12, EmSpacing.screenH, EmSpacing.s12), child: d.footer),
          ),
        ),
    ]);
  }

  Widget _content(BuildContext context, DetailSheetData d) {
    switch (d.state) {
      case DetailSheetState.loading:
        return ListView(controller: scroll, children: const [SizedBox(height: EmSpacing.s32), EmLoading(label: 'Loading details')]);
      case DetailSheetState.error:
        return ListView(controller: scroll, children: [EmErrorState(message: d.errorMessage, onRetry: d.onRetry, scroll: false)]);
      case DetailSheetState.ready:
        break;
    }
    final fields = d.fields.where((f) => f.visible).toList();
    final sections = d.sections.where((s) => s.fields.any((f) => f.visible)).toList();
    final longText = d.longText?.trim() ?? '';
    final stack = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(EmSpacing.screenH, EmSpacing.s16, EmSpacing.screenH, EmSpacing.s24),
      children: [
        if (d.statusLabel != null && d.statusLabel!.isNotEmpty) ...[
          Align(alignment: AlignmentDirectional.centerStart, child: EmChip.status(label: d.statusLabel!, tone: d.statusTone)),
          const SizedBox(height: EmSpacing.s8),
        ],
        Semantics(header: true, child: Text(d.title, key: const Key('detail_title'), style: EmType.heading.copyWith(color: EmColors.ink))),
        if (d.notice != null && d.notice!.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s12),
          DecoratedBox(
            key: const Key('detail_notice'),
            decoration: const BoxDecoration(color: EmColors.warningContainer, borderRadius: EmRadius.controlAll),
            child: Padding(
              padding: EmSpacing.cardPadCompact,
              child: Text(d.notice!, style: EmType.body.copyWith(color: EmColors.onWarningContainer)),
            ),
          ),
        ],
        if (fields.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s16),
          for (final f in fields) _FieldRow(f, stack: stack),
        ],
        if (longText.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s16),
          if (d.longTextLabel != null) _Label(d.longTextLabel!),
          d.longTextIsRich
              ? RichTextView(longText)
              : Text(longText, key: const Key('detail_long_text'), style: EmType.bodyRegular.copyWith(color: EmColors.ink, height: 1.5)),
        ],
        for (final s in sections) ...[
          const SizedBox(height: EmSpacing.s16),
          DecoratedBox(
            key: Key('detail_section_${s.title}'),
            decoration: const BoxDecoration(color: EmColors.primaryTint, borderRadius: EmRadius.controlAll),
            child: Padding(
              padding: EmSpacing.cardPad,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label(s.title),
                for (final f in s.fields.where((f) => f.visible)) _FieldRow(f, stack: stack),
              ]),
            ),
          ),
        ],
        if (d.attachments.isNotEmpty) ...[
          const SizedBox(height: EmSpacing.s16),
          const _Label('Attachments'),
          for (final a in d.attachments)
            InkWell(
              key: ValueKey('detail_attachment_${a.url}'),
              onTap: () => (onOpenAttachment ?? ExternalLinks.openWithConfirm)(a.url),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: EmSpacing.minTouch),
                child: Row(children: [
                  const Icon(Icons.attach_file_rounded, size: EmSpacing.s20, color: EmColors.primary),
                  const SizedBox(width: EmSpacing.s8),
                  Expanded(child: Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: EmType.body.copyWith(color: EmColors.primary))),
                  const Icon(Icons.open_in_new_rounded, size: EmSpacing.s16, color: EmColors.primary),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: EmSpacing.s4),
        child: Text(text, style: EmType.label.copyWith(fontWeight: FontWeight.w700, color: EmColors.textSecondary)),
      );
}

class _FieldRow extends StatelessWidget {
  const _FieldRow(this.field, {required this.stack});
  final DetailField field;
  final bool stack;

  @override
  Widget build(BuildContext context) {
    final label = Text(field.label, style: EmType.caption.copyWith(color: EmColors.textSecondary));
    final value = Text(field.value!, style: EmType.body.copyWith(color: EmColors.ink));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EmSpacing.s4),
      child: Semantics(
        container: true,
        label: '${field.label}: ${field.value}',
        excludeSemantics: true,
        child: stack
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [label, value])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: label), const SizedBox(width: EmSpacing.s12), Expanded(flex: 3, child: value)]),
      ),
    );
  }
}
