import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_spacing.dart';
import '../tokens/em_typography.dart';

/// iOS shows the number / decimal keypad without a return key, so `textInputAction.next` cannot move focus and the
/// keyboard cannot be dismissed. This wraps a screen and, on iOS only, docks a Prev / Next / Done bar above the keyboard
/// while a numeric-only field has focus. Prev and Next use the focus traversal order (so `ExcludeFocus` toggles are
/// skipped exactly as `textInputAction.next` skips them); Done unfocuses. Android and every other platform: untouched.
///
/// The wrapped scaffold sees the bar's height as extra keyboard inset, so the focused field and the bottom bars stay
/// above the bar instead of under it.
class EmKeyboardAccessory extends StatefulWidget {
  const EmKeyboardAccessory({super.key, required this.child, this.insetBody = true});

  final Widget child;

  /// False for a scaffold that does not resize for the keyboard: the bar is still shown, the body is not shifted.
  final bool insetBody;

  @override
  State<EmKeyboardAccessory> createState() => _EmKeyboardAccessoryState();
}

class _EmKeyboardAccessoryState extends State<EmKeyboardAccessory> {
  static const double barHeight = EmSpacing.minTouch;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  /// True when the primary focus is a numeric-only text field that belongs to this screen (not a dialog above it).
  bool _numericFieldFocused() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    final editable = ctx.findAncestorWidgetOfExactType<EditableText>();
    if (editable == null || ctx.findAncestorStateOfType<_EmKeyboardAccessoryState>() != this) return false;
    final type = editable.keyboardType.index;
    return type == TextInputType.number.index || type == TextInputType.phone.index;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final show = defaultTargetPlatform == TargetPlatform.iOS && mq.viewInsets.bottom > 0 && _numericFieldFocused();
    final inner = show && widget.insetBody ? mq.copyWith(viewInsets: mq.viewInsets.copyWith(bottom: mq.viewInsets.bottom + barHeight)) : mq;
    return Stack(
      fit: StackFit.expand,
      children: [
        MediaQuery(data: inner, child: widget.child),
        if (show)
          Positioned(
            left: 0,
            right: 0,
            bottom: mq.viewInsets.bottom,
            child: const _Bar(),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    // ExcludeFocus: tapping the bar must never take focus from the field (that would close the keyboard).
    return ExcludeFocus(
      child: Material(
        key: const Key('kbd_toolbar'),
        color: EmColors.surface,
        child: DecoratedBox(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: EmColors.border))),
          child: SizedBox(
            height: _EmKeyboardAccessoryState.barHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: EmSpacing.s4),
              child: Row(children: [
                IconButton(
                  key: const Key('kbd_prev'),
                  tooltip: 'Previous field',
                  color: EmColors.primary,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                  onPressed: () => FocusManager.instance.primaryFocus?.previousFocus(),
                ),
                IconButton(
                  key: const Key('kbd_next'),
                  tooltip: 'Next field',
                  color: EmColors.primary,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: () => FocusManager.instance.primaryFocus?.nextFocus(),
                ),
                const Spacer(),
                TextButton(
                  key: const Key('kbd_done'),
                  style: TextButton.styleFrom(foregroundColor: EmColors.primary, minimumSize: const Size(EmSpacing.minTouch, EmSpacing.minTouch)),
                  onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                  child: Text('Done', style: EmType.label.copyWith(color: EmColors.primary)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
