import 'package:flutter/material.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../shared/widgets/goldenity_page_header.dart';

/// Manajemen Meja — grid meja + QR + detail sesi (backend `/api/v1/tables` siap).
/// TODO(jalur-c): implementasi penuh sesuai Figma `TableManager`.
class TableManagementScreen extends StatelessWidget {
  const TableManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: GoldenityColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const GoldenityPageHeader(
          title: 'Manajemen Meja',
          subtitle: 'Meja, QR, dan sesi pesanan pelanggan',
          dense: true,
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.table_restaurant_rounded, size: 44, color: GoldenityColors.disabled),
              SizedBox(height: GoldenitySpacing.md),
              Text('Layar Manajemen Meja sedang dibangun',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: GoldenitySpacing.xs),
              Text('Backend sudah siap (grid meja, QR, detail sesi, tutup meja).',
                  style: TextStyle(color: GoldenityColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
