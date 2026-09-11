import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_typography.dart';

/// Stepper qty — Design System handoff §05.
/// `−` : bg `#EFF6FF` + border `#E2E8F0`, glyph `#1D4ED8`. Disabled saat qty≤min.
/// `+` : bg solid `#1D4ED8`, glyph putih. Disabled saat qty≥max.
/// Disabled: bg `#F8FAFC`, glyph `#CBD5E1`, border `#E2E8F0`.
/// Nilai di tengah: JetBrains Mono w700.
class GoldenityCounterButton extends StatelessWidget {
  const GoldenityCounterButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.buttonSize = 28.0,
    this.expand = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final double buttonSize;

  /// Saat true, stepper mengisi seluruh lebar yang tersedia dengan `−` di
  /// kiri dan `+` di kanan (dipakai kartu grid produk POS — Figma arch-sleek).
  /// Default false = compact, nempel jadi satu grup (dipakai di dialog).
  final bool expand;

  bool get _canMinus => value > min;
  bool get _canPlus => value < max;

  @override
  Widget build(BuildContext context) {
    final valueLabel = Text(
      '$value',
      style: const TextStyle(
        fontFamily: GoldenityTypography.fontFamilyMono,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: GoldenityColors.text,
        height: 1,
      ),
    );
    final minusBtn = _Btn(
      icon: Icons.remove_rounded,
      size: buttonSize,
      enabled: _canMinus,
      filled: false,
      onTap: _canMinus ? () => onChanged(value - 1) : null,
    );
    final plusBtn = _Btn(
      icon: Icons.add_rounded,
      size: buttonSize,
      enabled: _canPlus,
      filled: true,
      onTap: _canPlus ? () => onChanged(value + 1) : null,
    );

    if (expand) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          minusBtn,
          Expanded(child: Center(child: valueLabel)),
          plusBtn,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        minusBtn,
        Container(
          constraints: BoxConstraints(minWidth: buttonSize * 1.15),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: valueLabel,
        ),
        plusBtn,
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.size,
    required this.enabled,
    required this.filled,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final bool enabled;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final Color border;
    if (!enabled) {
      bg = GoldenityColors.surface2;
      fg = GoldenityColors.textXMuted;
      border = GoldenityColors.border;
    } else if (filled) {
      bg = GoldenityColors.primary;
      fg = Colors.white;
      border = Colors.transparent;
    } else {
      bg = GoldenityColors.primaryLight;
      fg = GoldenityColors.primary;
      border = GoldenityColors.border;
    }
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(GoldenityRadius.sm),
          ),
          child: Icon(icon, size: size * 0.55, color: fg),
        ),
      ),
    );
  }
}
