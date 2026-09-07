import 'package:flutter/material.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../shared/widgets/goldenity_page_header.dart';

/// Daftar Web Order (kasir) — terima/tolak/ubah status (backend `/api/v1/web-orders` siap).
/// TODO(jalur-c): implementasi penuh sesuai Figma `WebOrdersManager`.
class WebOrdersScreen extends StatelessWidget {
  const WebOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: GoldenityColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const GoldenityPageHeader(
          title: 'Web Orders',
          subtitle: 'Pesanan masuk dari QR meja pelanggan',
          dense: true,
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.delivery_dining_rounded, size: 44, color: GoldenityColors.disabled),
              SizedBox(height: GoldenitySpacing.md),
              Text('Layar Web Orders sedang dibangun',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              SizedBox(height: GoldenitySpacing.xs),
              Text('Backend siap: list/terima/tolak/ubah status + notifikasi real-time.',
                  style: TextStyle(color: GoldenityColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
