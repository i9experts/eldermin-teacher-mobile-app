import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/design/design.dart';

/// How much of the screen the photo takes on a signed-out screen.
enum AuthPhotoSize {
  /// Sign in: the photo fills the top ~55% and fades into the navy.
  tall(0.55, Alignment.topCenter),

  /// Forgot / reset password: a shorter photo.
  short(0.34, Alignment(0, -0.78));

  const AuthPhotoSize(this.fraction, this.alignment);
  final double fraction;

  /// Where the photo sits in its box: the short box shows the photo shifted up a little so the faces stay
  /// above the overlay's ramp (and clear of the status bar).
  final Alignment alignment;

  /// Share of a screen [height] dp tall: the tall photo gives way a little on small phones (< 700 dp, the iPhone SE)
  /// so the whole form still fits without scrolling.
  double fractionFor(double height) => this == tall && height < compactHeight ? compactTall : fraction;

  static const double compactHeight = 700, compactTall = 0.46;
}

/// Shared layout for the signed-out screens (login, forgot / reset password):
/// the first photo at the top fading into the navy page, the logo tile (the
/// splash landing anchor) on it, then the heading, the subtitle and the form on
/// the navy. The content rises and its items stagger in; the photo collapses to
/// a strip when the keyboard opens so the fields and the button stay in view.
/// Scrolls. See MOTION_SPEC.md 3.3 / 3.4 / 7.
///
/// Everything below the photo's strong line (EmPhotoOverlay) is text on the
/// overlay, so the content starts there and is checked against the worst case.
class AuthPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  /// Sign in has the tall photo; the others the short one.
  final AuthPhotoSize photoSize;

  /// Replaces the logo on the photo (the assembled success glyph).
  final Widget? glyph;

  /// Shakes the content whenever this changes (an error).
  final ValueListenable<int>? shake;

  const AuthPageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.photoSize = AuthPhotoSize.short,
    this.glyph,
    this.shake,
  });

  /// Strong line of the photo's overlay as a fraction of the photo box: content starts here.
  static const double photoSafeTop = 0.78;
  static final double contentStart = EmPhotoOverlay.strongLine(photoSafeTop);

  static const double logoTile = 64, glyphTile = 104, maxContentWidth = 420;

  @override
  Widget build(BuildContext context) {
    // read here, above the scaffold: it removes the keyboard inset from its body's MediaQuery
    final reduced = EmReduceMotion.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final tile = glyph != null ? glyphTile : logoTile;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final full = screenHeight * photoSize.fractionFor(screenHeight);
    // the keyboard collapses the photo to a strip that still holds the logo tile
    final collapsed = top + EmSpacing.s12 + tile + EmSpacing.s24;
    final photoHeight = keyboard ? (collapsed < full ? collapsed : full) : full;
    return EmEntranceHost(
      builder: (context, entrance) => EmEntrance(
        animation: entrance,
        child: EmScaffold(
          extendBody: false,
          wash: false,
          backgroundColor: EmColors.primaryDark,
          systemOverlay: SystemUiOverlayStyle.light,
          body: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: photoHeight),
                    duration: reduced ? Duration.zero : EmMotion.slow,
                    curve: EmMotion.emphasized,
                    builder: (context, h, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // the photo is taller than this box; the content below overlaps its faded lower part
                        SizedBox(
                          height: h * contentStart,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                height: h,
                                child: EmPhotoBackdrop(
                                  key: const Key('auth_photo'),
                                  image: EmAuthPhotos.provider(EmAuthPhotos.photo1),
                                  alignment: photoSize.alignment,
                                  safeTop: photoSafeTop,
                                  bottomAlpha: 1,
                                ),
                              ),
                              // top corner, clear of the people in the photo
                              PositionedDirectional(
                                top: top + EmSpacing.s12,
                                end: EmSpacing.s24,
                                child: glyph != null
                                    ? EmLogoTile(size: glyphTile, color: EmColors.primaryDark, child: glyph)
                                    : const EmLogoAnchor(child: EmLogoTile(size: logoTile)),
                              ),
                              if (showBack)
                                PositionedDirectional(
                                  top: top + EmSpacing.s8,
                                  start: EmSpacing.s16,
                                  child: Builder(builder: (context) {
                                    final rtl = Directionality.of(context) == TextDirection.rtl;
                                    return EmIconCircleButton(
                                      icon: rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                                      semanticLabel: 'Back',
                                      tooltip: 'Back',
                                      onTap: () => Navigator.maybeOf(context)?.maybePop(),
                                    );
                                  }),
                                ),
                            ],
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(EmSpacing.s24, 0, EmSpacing.s24, EmSpacing.s24),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                                child: _rise(entrance, _content()),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Heading (accent: large bold only), muted subtitle, then the form, all on the navy ([EmOnDark]).
  Widget _content() {
    return EmOnDark(
      child: Builder(
        builder: (context) => TextButtonTheme(
          data: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: EmColors.onPrimaryDark)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title,
                    key: const Key('auth_title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EmType.photoTitle.copyWith(color: EmColors.accent)),
              ),
              const SizedBox(height: EmSpacing.s8),
              Text(subtitle,
                  key: const Key('auth_subtitle'),
                  style: EmType.body.copyWith(color: EmOnDark.muted(context), fontWeight: FontWeight.w400)),
              const SizedBox(height: EmSpacing.s20),
              child,
            ],
          ),
        ),
      ),
    );
  }

  /// The content rises [EmMotion.riseDistance] while it fades in; shakes on error.
  Widget _rise(Animation<double> entrance, Widget content) {
    final a = CurvedAnimation(parent: entrance, curve: EmEntrancePlan.card);
    Widget c = AnimatedBuilder(
      animation: a,
      child: content,
      builder: (context, child) => Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, EmMotion.riseDistance * (1 - a.value)), child: child),
      ),
    );
    if (shake != null) c = EmShake(trigger: shake!, child: c);
    return c;
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
