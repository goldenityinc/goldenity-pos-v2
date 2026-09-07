import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_elevation.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_spacing.dart';

/// Kartu section back-office bergaya "Kinasih UI" (DESIGN_SYSTEM.md §4).
///
/// Satu widget reusable menggantikan pola `Container(decoration…) → Column(
/// Padding(Row(icon-box, title)), Divider, konten)` yang selama ini
/// di-copy-paste di Dashboard / Finance / Riwayat / Inventaris / Kategori.
///
/// - Surface putih, radius `xl` (12px), border tipis `border`, shadow `card`.
/// - Header opsional: kotak ikon 36×36 (tint), judul 14/800, `headerTrailing`
///   opsional di kanan, `headerSubtitle` opsional di bawah judul.
/// - Divider tipis antara header dan konten (bisa dimatikan).
class GoldenitySectionCard extends StatelessWidget {
  const GoldenitySectionCard({
    super.key,
    this.title,
    this.icon,
    this.iconColor,
    this.iconBackground,
    this.headerTrailing,
    this.headerSubtitle,
    this.showDivider = true,
    this.padding = const EdgeInsets.all(GoldenitySpacing.md),
    required this.child,
  });

  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBackground;
  final Widget? headerTrailing;
  final String? headerSubtitle;
  final bool showDivider;
  final EdgeInsetsGeometry padding;
  final Widget child;

  bool get _hasHeader => title != null || headerTrailing != null;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fg = iconColor ?? GoldenityColors.primary;
    final bg = iconBackground ?? GoldenityColors.primaryLight;

    return Container(
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: GoldenityElevation.card,
      ),
      // `Material` transparan supaya `ListTile`/`SwitchListTile` di dalam kartu
      // tetap merender ink-ripple dengan benar (tanpa ini Flutter warning
      // "ListTile background color or ink splashes may be invisible").
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
          if (_hasHeader) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GoldenitySpacing.md,
                GoldenitySpacing.md,
                GoldenitySpacing.md,
                GoldenitySpacing.sm,
              ),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                      ),
                      child: Icon(icon, color: fg, size: 20),
                    ),
                    const SizedBox(width: GoldenitySpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (title != null)
                          Text(
                            title!,
                            style: textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        if (headerSubtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            headerSubtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: GoldenityColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
            ),
            if (showDivider)
              const Divider(height: 1, color: GoldenityColors.border),
          ],
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
