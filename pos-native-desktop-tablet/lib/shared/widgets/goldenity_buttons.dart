import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_radius.dart';

/// Tombol aksi "+ Tambah …" konsisten di seluruh back-office.
/// Figma arch-sleek: pill biru `#1D4ED8`, teks putih 13/800, radius 10,
/// TANPA shadow berat / M3 tint (yang bikin terlihat "hitam").
class GoldenityAddButton extends StatelessWidget {
  const GoldenityAddButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.add_rounded,
    this.color,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? GoldenityColors.primary;
    return Material(
      color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol ikon aksi (refresh, dsb) — surface putih + border, ikon muted.
/// Bukan hitam pekat seperti `IconButton` default di AppBar.
class GoldenityIconAction extends StatelessWidget {
  const GoldenityIconAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: GoldenityColors.surface,
      borderRadius: BorderRadius.circular(GoldenityRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        onTap: loading ? null : onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            border: Border.all(color: GoldenityColors.border),
          ),
          child: loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 18, color: GoldenityColors.text2),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

/// Tombol sekunder (outline) — dipakai di drawer / dialog aksi.
class GoldenityOutlineButton extends StatelessWidget {
  const GoldenityOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.borderColor,
    this.height = 42,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final Color? borderColor;
  final double height;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? GoldenityColors.text2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        onTap: onTap,
        child: Container(
          height: height,
          width: fullWidth ? double.infinity : null,
          alignment: Alignment.center,
          padding: fullWidth ? null : const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            border: Border.all(color: borderColor ?? GoldenityColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tombol utama solid (fill) — dipakai di drawer / dialog aksi.
class GoldenityFillButton extends StatelessWidget {
  const GoldenityFillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color,
    this.height = 42,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final double height;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? GoldenityColors.primary;
    return Material(
      color: onTap == null ? bg.withValues(alpha: 0.5) : bg,
      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        onTap: busy ? null : onTap,
        child: Container(
          height: height,
          width: double.infinity,
          alignment: Alignment.center,
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 15, color: Colors.white),
                      const SizedBox(width: 6),
                    ],
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }
}
