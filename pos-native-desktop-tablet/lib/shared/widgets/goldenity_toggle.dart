import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_spacing.dart';

/// Toggle on/off — Design System handoff. Pill halus tanpa border/ring,
/// track + thumb animasi, satu sumber kebenaran untuk SEMUA switch di app
/// (menggantikan `Switch`/`Switch.adaptive`/`SwitchListTile.adaptive` bawaan
/// Flutter, yang di Windows/Material 3 merender status OFF sebagai lingkaran
/// kecil bergaris — tidak konsisten dengan status ON yang sudah bagus).
class GoldenityToggle extends StatelessWidget {
  const GoldenityToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.width = 40.0,
    this.height = 22.0,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final double width;
  final double height;

  bool get _enabled => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final Color onColor = activeColor ?? GoldenityColors.primary;
    final Color trackColor = !_enabled
        ? (value ? onColor.withValues(alpha: 0.35) : GoldenityColors.surface2)
        : (value ? onColor : GoldenityColors.border2);
    final double thumbSize = height - 6;

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: _enabled ? () => onChanged!(!value) : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(GoldenityRadius.full),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: thumbSize,
            height: thumbSize,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0x26000000), blurRadius: 3, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris "judul + (subjudul) + toggle" — pengganti drop-in untuk
/// `SwitchListTile.adaptive(title:, subtitle:, value:, onChanged:)` yang
/// dipakai di beberapa layar (Product Builder, dll), pakai [GoldenityToggle].
class GoldenitySwitchRow extends StatelessWidget {
  const GoldenitySwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.activeColor,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      borderRadius: BorderRadius.circular(GoldenityRadius.sm),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? GoldenitySpacing.xs : GoldenitySpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: (tt.bodyMedium ?? const TextStyle()).copyWith(
                        fontWeight: FontWeight.w600,
                        color: GoldenityColors.text,
                      )),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: tt.bodySmall?.copyWith(color: GoldenityColors.text2)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            GoldenityToggle(value: value, onChanged: onChanged, activeColor: activeColor),
          ],
        ),
      ),
    );
  }
}
