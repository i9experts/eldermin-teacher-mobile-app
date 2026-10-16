import 'package:flutter/material.dart';
import '../tokens/em_colors.dart';
import '../tokens/em_motion.dart';
import '../tokens/em_radius.dart';
import '../tokens/em_typography.dart';

class EmSegment<T> {
  const EmSegment(this.value, this.label);
  final T value;
  final String label;
}

/// White fully-rounded track with a filled pill on the selected segment
/// (Day / Week / Month). Height 52, each segment is a 48dp+ target.
class EmSegmentedTabs<T> extends StatelessWidget {
  const EmSegmentedTabs({super.key, required this.segments, required this.selected, required this.onChanged});

  final List<EmSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: EmColors.surface, borderRadius: EmRadius.pillAll),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in segments)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: s.value == selected,
                        label: s.label,
                        excludeSemantics: true,
                        onTap: () => onChanged(s.value),
                        child: AnimatedContainer(
                          duration: EmMotion.normal,
                          decoration: BoxDecoration(color: s.value == selected ? EmColors.primaryLight : Colors.transparent, borderRadius: EmRadius.pillAll),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              borderRadius: EmRadius.pillAll,
                              onTap: () => onChanged(s.value),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 8),
                                  child: Text(
                                    s.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: (s.value == selected ? EmType.label : EmType.body).copyWith(
                                      color: s.value == selected ? EmColors.ink : EmColors.textSecondary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
    );
  }
}
