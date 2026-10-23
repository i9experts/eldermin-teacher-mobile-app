import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../tokens/em_colors.dart';
import 'em_keyboard_toolbar.dart';

/// Brand-tint screen with the soft decorative wash in the top-end corner
/// (REFERENCE_SPEC section 1). Pair with [EmAppBar] and [EmBottomNav].
class EmScaffold extends StatelessWidget {
  const EmScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.wash = true,
    this.extendBody = true,
    this.resizeToAvoidBottomInset = true,
    this.systemOverlay = SystemUiOverlayStyle.dark,
    this.backgroundColor = EmColors.background,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool wash;

  /// True lets content scroll beneath the nav bar and FAB overlap; pad the
  /// scroll view with `EmSpacing.navClearance`.
  final bool extendBody;
  final bool resizeToAvoidBottomInset;

  /// Status-bar icon style. Default dark (this scaffold is a light tint); a
  /// screen that sets another style (the splash) does not leak it to the next.
  final SystemUiOverlayStyle systemOverlay;

  /// Page colour (navy on the photo auth screens).
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // The app bar lives inside the same stack as the wash, so the decorative
    // circle runs behind it instead of being cut off at the app bar's bottom edge.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlay,
      child: EmKeyboardAccessory(
        insetBody: resizeToAvoidBottomInset,
        child: Scaffold(
          backgroundColor: backgroundColor,
          extendBody: extendBody,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
          body: Stack(
            children: [
              if (wash)
                PositionedDirectional(
                  top: -110,
                  end: -90,
                  child: IgnorePointer(
                    child: ExcludeSemantics(
                      child: Container(
                        key: const Key('em_wash'),
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EmColors.primaryContainer.withAlpha(140),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: appBar == null
                    ? body
                    : Column(children: [appBar!, Expanded(child: body)]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
