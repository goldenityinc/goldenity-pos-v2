import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';

class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({
    super.key,
    required this.orderId,
    required this.grandTotal,
    required this.paymentMethodLabel,
    required this.transactionTime,
  });

  final String orderId;
  final num grandTotal;
  final String paymentMethodLabel;
  final DateTime transactionTime;

  static const String kPaymentMethodCashLabel = 'TUNAI';
  static const String kPaymentMethodQrisLabel = 'QRIS';
  static const String kPaymentMethodCardLabel = 'KARTU DEBIT/KREDIT';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final timeFormatter = DateFormat('dd MMMM yyyy · HH:mm', 'id_ID');

    return Scaffold(
      backgroundColor: GoldenityColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GoldenitySpacing.xxl * 1.5),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(GoldenitySpacing.xl * 1.2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GoldenityRadius.xl),
              border: Border.all(color: GoldenityColors.border, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 40,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: GoldenityColors.success.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: GoldenityColors.success,
                  ),
                ),
                const SizedBox(height: GoldenitySpacing.xl),
                Text(
                  'Pembayaran Berhasil',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: GoldenitySpacing.xs),
                Text(
                  'Transaksi Order #$orderId telah dicatat.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: GoldenityColors.text2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: GoldenitySpacing.xl),
                Container(
                  decoration: BoxDecoration(
                    color: GoldenityColors.surface2,
                    borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                    border: Border.all(color: GoldenityColors.border),
                  ),
                  padding: const EdgeInsets.all(GoldenitySpacing.md),
                  child: Column(
                    children: [
                      _buildDetailRow(
                        textTheme,
                        label: 'Nomor Order',
                        value: '#$orderId',
                        isValueBold: true,
                      ),
                      const SizedBox(height: GoldenitySpacing.sm),
                      _buildDetailRow(
                        textTheme,
                        label: 'Metode Bayar',
                        value: paymentMethodLabel,
                      ),
                      const SizedBox(height: GoldenitySpacing.sm),
                      _buildDetailRow(
                        textTheme,
                        label: 'Waktu Transaksi',
                        value: timeFormatter.format(transactionTime),
                      ),
                      const SizedBox(height: GoldenitySpacing.sm),
                      const Divider(height: 24, thickness: 1, color: GoldenityColors.border),
                      _buildDetailRow(
                        textTheme,
                        label: 'Total Dibayar',
                        value: currencyFormatter.format(grandTotal),
                        isHighlight: true,
                        isValueBold: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: GoldenitySpacing.xl * 1.4),
                GoldenityPrimaryButton(
                  label: 'Kembali ke POS',
                  icon: Icons.storefront_rounded,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(height: GoldenitySpacing.md),
                Text(
                  'Struk cetak akan tersedia bersama fitur Printer Fase B.',
                  style: textTheme.labelSmall?.copyWith(
                    color: GoldenityColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    TextTheme textTheme, {
    required String label,
    required String value,
    bool isValueBold = false,
    bool isHighlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: GoldenityColors.text2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: GoldenitySpacing.sm),
        Text(
          value,
          textAlign: TextAlign.right,
          style: (isHighlight
                  ? textTheme.titleMedium
                  : textTheme.bodyMedium)
              ?.copyWith(
            color: isHighlight ? GoldenityColors.success : GoldenityColors.text,
            fontWeight: isValueBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
