import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

class GoldenityVariantCheckboxSelector<T> extends StatelessWidget {
  const GoldenityVariantCheckboxSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.labelBuilder,
  });

  final List<T> options;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;
  final String Function(T option)? labelBuilder;

  void _toggle(T opt) {
    final Set<T> newSet = Set<T>.of(selected);
    if (newSet.contains(opt)) {
      newSet.remove(opt);
    } else {
      newSet.add(opt);
    }
    onChanged(newSet);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((T opt) {
        final bool isSelected = selected.contains(opt);
        final String label = labelBuilder?.call(opt) ?? opt.toString();
        return GestureDetector(
          onTap: () => _toggle(opt),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(minWidth: 90),
            decoration: BoxDecoration(
              color: isSelected
                  ? GoldenityBizColors.retail.light
                  : GoldenityColors.surface,
              borderRadius: BorderRadius.circular(GoldenityRadius.lg),
              border: Border.all(
                color: isSelected
                    ? GoldenityBizColors.retail.base
                    : GoldenityColors.border,
                width: isSelected ? 1.5 : 1,
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
                    color: isSelected
                        ? GoldenityBizColors.retail.base
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isSelected
                          ? GoldenityBizColors.retail.base
                          : GoldenityColors.border2,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: GoldenityTypography.fontFamilySans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? GoldenityBizColors.retail.base
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
