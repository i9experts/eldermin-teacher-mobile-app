import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';

/// Shared layout for the signed-out screens (login, forgot / reset password):
/// a navy hero (logo, title, subtitle over a drifting constellation) and the
/// form card below it. The card rises and its items stagger in; the hero
/// collapses when the keyboard opens so the form and the button stay in view.
/// Scrolls. See MOTION_SPEC.md 3.3 / 3.4.
class AuthPageShell extends StatefulWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  /// Wraps [child] in the form card (default). Turn off for content that
  /// brings its own surface.
  final bool card;

  /// The login screen has the tall hero; the others the compact one.
  final EmHeroSize heroSize;

  /// Replaces the logo in the hero (the assembled success glyph).
  final Widget? glyph;

  /// Shakes the card whenever this changes (an error).
  final ValueListenable<int>? shake;

  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.card = true,
    this.heroSize = EmHeroSize.compact,
    this.glyph,
    this.shake,
  });

  @override
  State<AuthPageShell> createState() => _AuthPageShellState();
}

class _AuthPageShellState extends State<AuthPageShell> with TickerProviderStateMixin {
  // the constellation: a slow loop (whole cycles per loop) at full strength, dimmed while collapsed
  late final AnimationController _time = AnimationController(vsync: this, duration: EmMotion.ambientPeriod);
  late final AnimationController _intensity = AnimationController(vsync: this, value: 1, duration: EmMotion.slow);
  bool _collapsed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !EmReduceMotion.of(context)) {
      _started = true;
      _time.repeat();
    }
    final collapsed = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (collapsed != _collapsed) {
      _collapsed = collapsed;
      _intensity.animateTo(collapsed ? 0.3 : 1, curve: EmMotion.standard);
    }
  }

  @override
  void dispose() {
    _time.dispose();
    _intensity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EmEntranceHost(
      builder: (context, entrance) => EmEntrance(
        animation: entrance,
        child: EmScaffold(
          extendBody: false,
          systemOverlay: SystemUiOverlayStyle.light,
          body: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EmAuthHero(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      size: widget.heroSize,
                      collapsed: _collapsed,
                      showBack: widget.showBack,
                      glyph: widget.glyph,
                      time: _time,
                      intensity: _intensity,
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(horizontal: EmSpacing.screenH, vertical: EmSpacing.s20),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _rise(entrance, widget.card ? AuthCard(child: widget.child) : widget.child),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The card rises [EmMotion.riseDistance] while it fades in; shakes on error.
  Widget _rise(Animation<double> entrance, Widget card) {
    final a = CurvedAnimation(parent: entrance, curve: EmEntrancePlan.card);
    Widget c = AnimatedBuilder(
      animation: a,
      child: card,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, EmMotion.riseDistance * (1 - a.value)), child: child),
      ),
    );
    if (widget.shake != null) c = EmShake(trigger: widget.shake!, child: c);
    return c;
  }
}

/// The form card: a blue gradient (primary -> primaryDark) instead of a white
/// surface. Everything inside sits on dark ([EmOnDark]): fields are transparent
/// with a white border (accent when focused), the primary button is the accent
/// fill, text buttons are white.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EmRadius.card),
        gradient:
            const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [EmColors.primary, EmColors.primaryDark]),
        boxShadow: EmShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(EmSpacing.s20),
        child: EmOnDark(
          child: TextButtonTheme(
            data: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: EmColors.onPrimaryDark)),
            child: child,
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
            child: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: EmOnDark.muted(context)),
          ),
        ),
      );
}
