import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_elevation.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_spacing.dart';
import '../../core/design/goldenity_typography.dart';

/// Kartu metrik back-office ("MetricCard" DESIGN_SYSTEM.md §4).
///
/// Kotak ikon 44×44 (tint semantic) + label kecil muted + angka besar
/// 28px/800 JetBrains Mono `tabular-nums`. Reusable — dipakai Dashboard &
/// Keuangan menggantikan `_StatCard` / `_FinanceStatCard` privat.
class GoldenityMetricCard extends StatelessWidget {
  const GoldenityMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
    this.iconBackground,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackground;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final fg = iconColor ?? GoldenityColors.primary;
    final bg = iconBackground ?? GoldenityColors.primaryLight;

    return Container(
      padding: const EdgeInsets.all(GoldenitySpacing.md),
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: GoldenityElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                ),
                child: Icon(icon, color: fg, size: 24),
              ),
              const SizedBox(width: GoldenitySpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: GoldenityColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: GoldenityTypography.fontFamilyMono,
              fontFeatures: [FontFeature.tabularFigures()],
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: GoldenityColors.text,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: GoldenitySpacing.xs),
            Text(
              caption!,
              style: textTheme.bodySmall?.copyWith(
                color: GoldenityColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
