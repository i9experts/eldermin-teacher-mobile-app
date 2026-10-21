import 'package:flutter/material.dart';
import '../../../../core/design/design.dart';

/// Shared layout for the signed-out screens (login, forgot / reset
/// password): tinted scaffold, logomark, title, subtitle, then the form on a
/// white card. Scrolls, and keeps the form reachable with the keyboard open.
class AuthPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  /// Wraps [child] in the white form card (default). Turn off for content that
  /// brings its own surface.
  final bool card;
  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.card = true,
  });

  @override
  Widget build(BuildContext context) {
    return EmScaffold(
      extendBody: false,
      appBar: showBack ? const EmAppBar() : null,
      body: SafeArea(
        top: !showBack,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - EmSpacing.s32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: EmLogomark(height: 72, semanticLabel: 'Eldermin')),
                      const SizedBox(height: EmSpacing.s20),
                      Semantics(
                        header: true,
                        child: Text(title, textAlign: TextAlign.center, style: EmType.display.copyWith(color: EmColors.ink)),
                      ),
                      const SizedBox(height: EmSpacing.s8),
                      Text(subtitle, textAlign: TextAlign.center, style: EmType.body.copyWith(color: EmColors.textSecondary, fontWeight: FontWeight.w400)),
                      const SizedBox(height: EmSpacing.s24),
                      if (card) EmCard(padding: const EdgeInsetsDirectional.all(EmSpacing.s20), child: child) else child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline message box: errors use the error container, notices the info
/// container; text is the dark on-container colour. Announced to screen readers.
class AuthBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const AuthBanner({super.key, required this.message, this.isError = true});

  @override
  Widget build(BuildContext context) {
    final tone = isError ? EmTone.error : EmTone.info;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.all(EmSpacing.s12),
        decoration: BoxDecoration(color: tone.background, borderRadius: EmRadius.mdAll),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(isError ? Icons.error_outline_rounded : Icons.info_outline_rounded, color: tone.foreground, size: 20),
            const SizedBox(width: EmSpacing.s8),
            Expanded(child: Text(message, style: EmType.label.copyWith(color: tone.foreground))),
          ],
        ),
      ),
    );
  }
}

/// Eye icon button for password fields (48dp target).
class PasswordVisibilityButton extends StatelessWidget {
  final bool obscured;
  final VoidCallback onToggle;
  const PasswordVisibilityButton({super.key, required this.obscured, required this.onToggle});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: obscured ? 'Show password' : 'Hide password',
        excludeSemantics: true,
        onTap: onToggle,
        child: InkResponse(
          onTap: onToggle,
          radius: 24,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: EmColors.textSecondary),
          ),
        ),
      );
}
