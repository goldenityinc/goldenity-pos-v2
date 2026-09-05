import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

class GoldenityVariantRadioSelector<T> extends StatelessWidget {
  const GoldenityVariantRadioSelector({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelBuilder,
  });

  final List<T> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String Function(T option)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((T opt) {
        final bool selected = value == opt;
        final String label = labelBuilder?.call(opt) ?? opt.toString();
        return GestureDetector(
          onTap: () => onChanged(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(minWidth: 90),
            decoration: BoxDecoration(
              color: selected
                  ? GoldenityColors.primaryLight
                  : GoldenityColors.surface,
              borderRadius: BorderRadius.circular(GoldenityRadius.lg),
              border: Border.all(
                color: selected
                    ? GoldenityColors.primary
                    : GoldenityColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected
                          ? GoldenityColors.primary
                          : GoldenityColors.border2,
                      width: 2,
                    ),
                    color: selected ? GoldenityColors.primary : Colors.white,
                  ),
                  child: selected
                      ? const Center(
                          child: SizedBox(
                            width: 7,
                            height: 7,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: GoldenityTypography.fontFamilySans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? GoldenityColors.primary
                        : GoldenityColors.text2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}
