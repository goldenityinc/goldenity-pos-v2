import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design/goldenity_colors.dart';
import '../../core/design/goldenity_elevation.dart';
import '../../core/design/goldenity_radius.dart';
import '../../core/design/goldenity_spacing.dart';
import '../../core/design/goldenity_typography.dart';
import '../sales/quick_cash_denominations.dart';
import 'goldenity_primary_button.dart';

class GoldenityCashTenderModal extends StatefulWidget {
  const GoldenityCashTenderModal({
    super.key,
    required this.totalAmount,
    this.initialReceived,
  });

  final double totalAmount;
  final double? initialReceived;

  static Future<CashTenderResult?> show(
    BuildContext context, {
    required double totalAmount,
    double? initialReceived,
  }) {
    return showDialog<CashTenderResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => GoldenityCashTenderModal(
        totalAmount: totalAmount,
        initialReceived: initialReceived,
      ),
    );
  }

  @override
  State<GoldenityCashTenderModal> createState() =>
      _GoldenityCashTenderModalState();
}

class CashTenderResult {
  CashTenderResult({required this.received, required this.change});
  final double received;
  final double change;
}

class _GoldenityCashTenderModalState extends State<GoldenityCashTenderModal> {
  late final TextEditingController _amountCtrl;
  final NumberFormat _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  double _received = 0;

  double get _change {
    final double d = _received - widget.totalAmount;
    return d < 0 ? 0 : d;
  }

  bool get _canConfirm => _received >= widget.totalAmount;

  /// Story 3.3 — pakai algoritma quick-cash bersama (LOCKED 4/4 Andre,
  /// `lib/shared/sales/quick_cash_denominations.dart`). Chip PAS (exact total)
  /// tampil pertama, lalu saran pecahan yang lebih besar.
  List<double> get _smartChips {
    final double total = widget.totalAmount;
    final chips = <double>[
      total,
      ...suggestedCashAmounts(total).map((n) => n.toDouble()),
    ];
    final seen = <double>{};
    return chips.where(seen.add).take(4).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _received = widget.initialReceived ?? widget.totalAmount;
    _amountCtrl =
        TextEditingController(text: _fmt.format(_received).replaceAll(',', ''));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _setAmount(double v) {
    setState(() {
      _received = v;
      _amountCtrl.text = _fmt.format(v).replaceAll(',', '');
    });
  }

  void _onAmountChanged(String s) {
    final String clean = s.replaceAll(RegExp(r'[^0-9]'), '');
    final double? parsed = double.tryParse(clean);
    if (parsed != null) {
      setState(() {
        _received = parsed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(GoldenitySpacing.md),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        decoration: BoxDecoration(
          color: GoldenityColors.surface,
          borderRadius: BorderRadius.circular(GoldenityRadius.xxxl),
          boxShadow: GoldenityElevation.modal,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Pembayaran Tunai',
              style: TextStyle(
                fontFamily: GoldenityTypography.fontFamilySans,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: GoldenityColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                const Text(
                  'Total Tagihan',
                  style: TextStyle(
                    fontFamily: GoldenityTypography.fontFamilySans,
                    color: GoldenityColors.text2,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmt.format(widget.totalAmount),
                  style: const TextStyle(
                    fontFamily: GoldenityTypography.fontFamilyMono,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: GoldenityColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Uang Diterima',
              style: TextStyle(
                fontFamily: GoldenityTypography.fontFamilySans,
                color: GoldenityColors.text2,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontFamily: GoldenityTypography.fontFamilyMono,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: GoldenityColors.text,
              ),
              decoration: const InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 14, right: 4),
                  child: Text(
                    'Rp ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: GoldenityColors.text,
                    ),
                  ),
                ),
                prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
              ),
              onChanged: _onAmountChanged,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _smartChips.map((double chip) {
                final bool isActive = (_received - chip).abs() < 0.01;
                return GestureDetector(
                  onTap: () => _setAmount(chip),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? GoldenityColors.primaryLight
                          : GoldenityColors.surface2,
                      borderRadius:
                          BorderRadius.circular(GoldenityRadius.full),
                      border: Border.all(
                        color: isActive
                            ? GoldenityColors.primary
                            : GoldenityColors.border,
                      ),
                    ),
                    child: Text(
                      _fmt.format(chip),
                      style: TextStyle(
                        fontFamily: GoldenityTypography.fontFamilyMono,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isActive
                            ? GoldenityColors.primary
                            : GoldenityColors.text2,
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(GoldenitySpacing.md),
              decoration: BoxDecoration(
                color: _canConfirm
                    ? GoldenityColors.successLight
                    : GoldenityColors.errorLight,
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    'Kembalian',
                    style: TextStyle(
                      fontFamily: GoldenityTypography.fontFamilySans,
                      fontSize: 13,
                      color: _canConfirm
                          ? GoldenityColors.success
                          : GoldenityColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _fmt.format(_change),
                    style: TextStyle(
                      fontFamily: GoldenityTypography.fontFamilyMono,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _canConfirm
                          ? GoldenityColors.success
                          : GoldenityColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                    child: const Text('Batal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoldenityPrimaryButton(
                    label: 'Konfirmasi',
                    onPressed: _canConfirm
                        ? () {
                            Navigator.of(context).pop(
                              CashTenderResult(
                                received: _received,
                                change: _change,
                              ),
                            );
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
