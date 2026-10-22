import 'package:flutter/widgets.dart';
import '../tokens/em_colors.dart';

/// Marks a subtree as sitting on a dark / blue-gradient surface (the auth card).
/// Fields, the primary button and the password eye restyle themselves from it:
/// transparent fill, white border, accent when focused, accent button.
class EmOnDark extends InheritedWidget {
  const EmOnDark({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<EmOnDark>() != null;

  /// Secondary text / icon colour: [textSecondary] on light surfaces, a light
  /// blue (>= 4.5:1 on the whole card gradient) on dark ones.
  static Color muted(BuildContext context) => of(context) ? EmColors.primaryContainer : EmColors.textSecondary;

  @override
  bool updateShouldNotify(EmOnDark old) => false;
}
