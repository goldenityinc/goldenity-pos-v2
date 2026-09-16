import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';

/// Chip pilihan pill — Design System handoff (sama persis gaya filter
/// kategori POS: `_CategoryChips` di product_list_screen.dart). Satu sumber
/// kebenaran untuk SEMUA chip pilihan di app, menggantikan `ChoiceChip`
/// bawaan Flutter yang defaultnya bergaris/outline gelap saat tidak
/// terpilih — tidak konsisten dengan pill chip lain di app.
class GoldenityChoiceChip extends StatelessWidget {
  const GoldenityChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.activeColor,
    this.dense = false,
    this.icon,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final Color? activeColor;
  final IconData? icon;

  /// Padding lebih ringkas (dipakai di ruang sempit, mis. kartu slot printer).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color onColor = activeColor ?? GoldenityColors.primary;
    final bool enabled = onSelected != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.full),
        onTap: enabled ? () => onSelected!(!selected) : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 6 : 8),
          decoration: BoxDecoration(
            color: !enabled
                ? GoldenityColors.surface2
                : selected
                    ? onColor
                    : GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.full),
            border: Border.all(
              color: !enabled
                  ? GoldenityColors.border
                  : selected
                      ? onColor
                      : GoldenityColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: dense ? 13 : 15,
                  color: !enabled
                      ? GoldenityColors.textXMuted
                      : selected
                          ? Colors.white
                          : GoldenityColors.text2,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: dense ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                  color: !enabled
                      ? GoldenityColors.textXMuted
                      : selected
                          ? Colors.white
                          : GoldenityColors.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
