import 'package:flutter/material.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_spacing.dart';

/// Judul halaman back-office ("PageHeader" DESIGN_SYSTEM.md §4):
/// judul 22/800 + subtitle muted + slot aksi di kanan.
///
/// Dipakai sebagai `title` di `AppBar` tiap layar back-office supaya semua
/// header seragam (bukan `Text` mentah dengan style beda-beda per screen).
/// Untuk `AppBar`, set `dense: true` agar ukurannya pas di toolbar.
class GoldenityPageHeader extends StatelessWidget {
  const GoldenityPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: (dense ? textTheme.titleLarge : textTheme.headlineMedium)
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: textTheme.bodySmall?.copyWith(
              color: GoldenityColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Versi header untuk dipakai di dalam body (bukan AppBar) — judul + subtitle
/// di kiri, `actions` di kanan, dengan padding bawah standar.
class GoldenityBodyHeader extends StatelessWidget {
  const GoldenityBodyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: GoldenitySpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: GoldenityPageHeader(title: title, subtitle: subtitle)),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: GoldenitySpacing.md),
            ...actions,
          ],
        ],
      ),
    );
  }
}
