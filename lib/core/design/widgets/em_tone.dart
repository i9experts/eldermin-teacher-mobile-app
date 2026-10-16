import 'package:flutter/painting.dart';
import '../tokens/em_colors.dart';

/// Semantic tone for status chips/tags: light container + dark text, never a
/// solid fill.
enum EmTone {
  neutral(EmColors.textSecondary, EmColors.primaryTint),
  info(EmColors.onInfoContainer, EmColors.infoContainer),
  success(EmColors.onSuccessContainer, EmColors.successContainer),
  warning(EmColors.onWarningContainer, EmColors.warningContainer),
  error(EmColors.onErrorContainer, EmColors.errorContainer),
  leave(EmColors.onStatusLeaveContainer, EmColors.statusLeaveContainer);

  const EmTone(this.foreground, this.background);
  final Color foreground;
  final Color background;
}
