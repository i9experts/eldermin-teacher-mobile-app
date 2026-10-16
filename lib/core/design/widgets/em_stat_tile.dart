import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';

/// Lighter-tint tile (radius 20): white icon circle, optional kebab, bold
/// value + small unit, caption label. Sits inside an [EmHeroCard].
///
/// The kebab has a 48dp target aligned to the tile's top-end corner; its glyph
/// is right-aligned so three tiles still fit side by side on a 320dp screen.
class EmStatTile extends StatelessWidget {
  const EmStatTile({
    super.key,
    required this.icon,
    required this.value,
    this.unit,
    required this.label,
    this.onMenu,
    this.menuLabel = 'More options',
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String? unit;
  final String label;

  /// Shows the vertical kebab when set.
  final VoidCallback? onMenu;
  final String menuLabel;
  final VoidCallback? onTap;

  static final TextStyle labelStyle = EmType.caption.copyWith(color: EmColors.textSecondary);

  /// Horizontal space a tile needs so [label] never breaks inside a word
  /// (longest word + the tile's inner padding), at the ambient text scale.
  static double minWidthFor(BuildContext context, String label) {
    final scaler = MediaQuery.textScalerOf(context);
    var longest = 0.0;
    for (final w in label.split(RegExp(r'\s+'))) {
      if (w.isEmpty) continue;
      final tp = TextPainter(text: TextSpan(text: w, style: labelStyle), textDirection: TextDirection.ltr, textScaler: scaler, maxLines: 1)..layout();
      if (tp.width > longest) longest = tp.width;
    }
    return longest + 12 + 8 + 2; // start/end padding + rounding slack
  }

  @override
  Widget build(BuildContext context) {
    final summary = '$label: $value${unit != null ? ' $unit' : ''}';
    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 48,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: EmColors.surface, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: EmColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // value + unit stay together; the unit may drop below the value
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: [
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.valueSmall.copyWith(color: EmColors.ink)),
              if (unit != null) Text(unit!, maxLines: 1, overflow: TextOverflow.ellipsis, style: EmType.caption.copyWith(color: EmColors.ink, fontWeight: FontWeight.w400)),
            ],
          ),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: labelStyle),
        ],
      ),
    );
    final tile = DecoratedBox(
      decoration: const BoxDecoration(color: EmColors.primaryTint, borderRadius: EmRadius.tileAll),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: EmRadius.tileAll,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Semantics(
              container: true,
              button: onTap != null,
              label: summary,
              onTap: onTap,
              excludeSemantics: true,
              child: onTap == null ? content : InkWell(onTap: onTap, child: content),
            ),
            if (onMenu != null)
              PositionedDirectional(
                top: 8,
                end: 0,
                child: Semantics(
                  button: true,
                  label: menuLabel,
                  excludeSemantics: true,
                  onTap: onMenu,
                  child: InkResponse(
                    onTap: onMenu,
                    radius: 24,
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Align(alignment: AlignmentDirectional.centerEnd, child: Padding(padding: EdgeInsetsDirectional.only(end: 6), child: Icon(Icons.more_vert_rounded, size: 20, color: EmColors.ink))),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return tile;
  }
}

/// Lays [tiles] out side by side while each tile is wide enough for its
/// longest label word (no mid-word wrapping); otherwise falls back to 2 + 1,
/// then stacked. Decided from the measured label words at the current text
/// scale and from the width, so it also switches when text scale > ~1.15.
class EmStatTileRow extends StatelessWidget {
  const EmStatTileRow({super.key, required this.tiles, this.gap = 8});

  final List<EmStatTile> tiles;
  final double gap;

  /// Columns used for [width] given the tiles' needs (exposed for tests).
  static int columnsFor(BuildContext context, List<EmStatTile> tiles, double width, {double gap = 8}) {
    if (tiles.isEmpty) return 1;
    var need = 0.0;
    for (final t in tiles) {
      final n = EmStatTile.minWidthFor(context, t.label);
      if (n > need) need = n;
    }
    // icon chip (40) + kebab glyph area also bound the minimum
    need = need < 88 ? 88 : need;
    for (var c = tiles.length; c > 1; c--) {
      if ((width - gap * (c - 1)) / c >= need) return c;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = columnsFor(context, tiles, constraints.maxWidth, gap: gap);
      final rows = <List<EmStatTile>>[];
      if (cols >= tiles.length) {
        rows.add(tiles);
      } else {
        // balanced: 3 tiles with 2 columns = 2 + 1
        for (var i = 0; i < tiles.length; i += cols) {
          rows.add(tiles.sublist(i, i + cols > tiles.length ? tiles.length : i + cols));
        }
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < rows[r].length; i++) ...[if (i > 0) SizedBox(width: gap), Expanded(child: rows[r][i])],
              ],
            ),
          ],
        ],
      );
    });
  }
}
