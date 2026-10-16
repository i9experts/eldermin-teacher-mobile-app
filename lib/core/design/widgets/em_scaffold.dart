import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmColors.background,
      extendBody: extendBody,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
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
                      color: EmColors.primaryContainer.withOpacity(0.55),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(child: body),
        ],
      ),
    );
  }
}
