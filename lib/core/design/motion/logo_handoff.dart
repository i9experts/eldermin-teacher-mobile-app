import 'package:flutter/widgets.dart';

/// Where the splash's logo lands. A destination screen wraps its header logo
/// in [EmLogoAnchor]; the splash overlay reads the anchor's rect each frame
/// of the flight and, while it flies, the anchor hides its child so the real
/// logo appears exactly under the flying one when the overlay is removed.
class EmLogoHandoff {
  EmLogoHandoff._();

  static GlobalKey? _anchor;

  /// True while the splash overlay is flying its logo to the anchor.
  static final ValueNotifier<bool> flying = ValueNotifier<bool>(false);

  static bool get hasAnchor => anchorBox != null;

  static RenderBox? get anchorBox {
    final o = _anchor?.currentContext?.findRenderObject();
    return (o is RenderBox && o.attached && o.hasSize) ? o : null;
  }

  /// The anchor's rect in [overlay]'s coordinates, or null when there is none.
  static Rect? anchorRectIn(RenderBox overlay) {
    final box = anchorBox;
    if (box == null || !overlay.attached) return null;
    final topLeft = overlay.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  @visibleForTesting
  static void reset() {
    _anchor = null;
    flying.value = false;
  }
}

class EmLogoAnchor extends StatefulWidget {
  const EmLogoAnchor({super.key, required this.child});
  final Widget child;

  @override
  State<EmLogoAnchor> createState() => _EmLogoAnchorState();
}

class _EmLogoAnchorState extends State<EmLogoAnchor> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    EmLogoHandoff._anchor = _key;
  }

  @override
  void dispose() {
    if (EmLogoHandoff._anchor == _key) EmLogoHandoff._anchor = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: EmLogoHandoff.flying,
      child: KeyedSubtree(key: _key, child: widget.child),
      // no wrapper at rest (a layer-free, pixel-identical tree); the GlobalKey keeps the logo's state across the swap
      builder: (context, flying, child) => flying ? Opacity(opacity: 0, alwaysIncludeSemantics: true, child: child) : child!,
    );
  }
}
