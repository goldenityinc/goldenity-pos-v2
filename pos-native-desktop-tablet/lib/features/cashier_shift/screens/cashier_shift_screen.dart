import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../../../core/models/shift_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/product_list_provider.dart';

class CashierShiftScreen extends ConsumerStatefulWidget {
  const CashierShiftScreen({super.key});

  @override
  ConsumerState<CashierShiftScreen> createState() => _CashierShiftScreenState();
}

class _CashierShiftScreenState extends ConsumerState<CashierShiftScreen> {
  bool _loading = false;
  String _errMsg = '';
  ShiftProfile? _current;
  bool _blindModeCashier = false;

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final DateFormat _dateTimeFormatter = DateFormat.yMd('id_ID').add_Hm();
  final TextEditingController _openingCashCtrl = TextEditingController(text: '0');
  final TextEditingController _actualCashCtrl = TextEditingController(text: '0');
  final TextEditingController _notesCtrl = TextEditingController();
  final GlobalKey<FormState> _openFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _closeFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _openingCashCtrl.dispose();
    _actualCashCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errMsg = '';
    });
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final shiftApi = ref.read(shiftApiServiceProvider);
      final current = await shiftApi.getCurrentShift(authToken: token);
      final bool blind = current?.blindActive ?? false;
      if (mounted) {
        setState(() {
          _current = current;
          _blindModeCashier = blind;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatCurrency(num value) {
    return _currencyFormatter.format(value);
  }

  num _parseCurrency(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return 0;
    return num.parse(cleaned);
  }

  String _formatCurrencyInput(String raw) {
    final numValue = _parseCurrency(raw);
    final formatted = _currencyFormatter.format(numValue);
    return formatted;
  }

  int _countCashTransactions(ShiftProfile shift) {
    final records = shift.salesRecords ?? [];
    return records.where((r) => r.paymentMethod.toUpperCase() == 'CASH').length;
  }

  num _sumCashSales(ShiftProfile shift) {
    final records = shift.salesRecords ?? [];
    num total = 0;
    for (final r in records) {
      if (r.paymentMethod.toUpperCase() == 'CASH' && r.status.toLowerCase() != 'refund') {
        total += r.cashReceived ?? r.total;
      }
    }
    return total;
  }

  num _sumRefunds(ShiftProfile shift) {
    final records = shift.salesRecords ?? [];
    num total = 0;
    for (final r in records) {
      if (r.status.toLowerCase() == 'refund' || (r.refundedAmount != null && r.refundedAmount! > 0)) {
        total += r.refundedAmount ?? r.total;
      }
    }
    return total;
  }

  Future<void> _openShift() async {
    final form = _openFormKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final shiftApi = ref.read(shiftApiServiceProvider);
      final openingCash = _parseCurrency(_openingCashCtrl.text);
      await shiftApi.openShift(authToken: token, openingCash: openingCash);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.success,
            content: Text('Shift berhasil dibuka pukul ${_dateTimeFormatter.format(DateTime.now())}'),
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeShift() async {
    if (_current == null) return;
    final form = _closeFormKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _loading = true);
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) throw Exception('Sesi tidak ditemukan');
      final shiftApi = ref.read(shiftApiServiceProvider);
      final actualCash = _parseCurrency(_actualCashCtrl.text);
      final notes = _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null;
      final closed = await shiftApi.closeShift(
        authToken: token,
        shiftId: _current!.id,
        actualCash: actualCash,
        notes: notes,
      );
      final discrepancy = closed.discrepancy;
      final message = closed.notes;

      if (mounted) {
        final expectedCash = closed.expectedCash ?? _current!.expectedCashLive ?? 0;
        await _showReconciliationDialog(expectedCash, actualCash, discrepancy ?? 0, message, _blindModeCashier);
        setState(() {
          _current = null;
          _actualCashCtrl.text = '0';
          _notesCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showReconciliationDialog(num expectedCash, num actualCash, num discrepancy, String? message, bool blindMode) async {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final isBalanced = discrepancy == 0;
    final isSurplus = discrepancy > 0;
    final discColor = isBalanced
        ? GoldenityColors.success
        : isSurplus
            ? GoldenityColors.success
            : GoldenityColors.error;
    final discBg = isBalanced
        ? GoldenityColors.successLight
        : isSurplus
            ? GoldenityColors.successLight
            : GoldenityColors.errorLight;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
        title: Row(
          children: [
            Icon(
              blindMode ? Icons.receipt_long_rounded : (isBalanced ? Icons.check_circle_rounded : Icons.receipt_long_rounded),
              color: blindMode ? GoldenityColors.primary : discColor,
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            const Text('Hasil Rekonsiliasi Shift'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: GoldenityColors.surface2,
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
              ),
              padding: const EdgeInsets.all(GoldenitySpacing.md),
              child: Column(
                children: [
                  _ReconRow(
                    label: 'Actual Cash',
                    value: _formatCurrency(actualCash),
                    textTheme: textTheme,
                  ),
                  if (!blindMode) ...[
                    const SizedBox(height: GoldenitySpacing.sm),
                    _ReconRow(
                      label: 'Expected Cash',
                      value: _formatCurrency(expectedCash),
                      textTheme: textTheme,
                    ),
                    const Divider(height: GoldenitySpacing.lg),
                    Container(
                      decoration: BoxDecoration(
                        color: discBg,
                        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                      ),
                      padding: const EdgeInsets.all(GoldenitySpacing.sm),
                      child: _ReconRow(
                        label: 'Discrepancy',
                        value: isBalanced
                            ? 'SEIMBANG (0)'
                            : isSurplus
                                ? '+ ${_formatCurrency(discrepancy)}'
                                : '- ${_formatCurrency(discrepancy.abs())}',
                        textTheme: textTheme,
                        valueColor: discColor,
                        isBold: true,
                      ),
                    ),
                  ],
                  if (blindMode) ...[
                    const SizedBox(height: GoldenitySpacing.md),
                    const Divider(),
                    const SizedBox(height: GoldenitySpacing.sm),
                    Text(
                      'Shift ditutup. Rekonsiliasi uang kas akan direview oleh manajemen/admin.',
                      style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.primary, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: GoldenitySpacing.md),
            if (message != null && message.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: biz.light,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                ),
                padding: const EdgeInsets.all(GoldenitySpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: biz.dark, size: 20),
                    const SizedBox(width: GoldenitySpacing.sm),
                    Expanded(
                      child: Text(
                        message,
                        style: textTheme.bodySmall?.copyWith(color: biz.dark, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          GoldenityPrimaryButton(
            label: 'OK, Tutup',
            height: 40,
            backgroundColor: biz.base,
            shadow: GoldenityElevation.btnPrimary,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    return Scaffold(
      backgroundColor: GoldenityColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Shift Kasir', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              'Buka / tutup shift kasir & rekonsiliasi',
              style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: biz.base,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: GoldenitySpacing.sm),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(GoldenitySpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: GoldenityColors.error),
                        const SizedBox(height: GoldenitySpacing.md),
                        Text(_errMsg, style: textTheme.bodyMedium),
                        const SizedBox(height: GoldenitySpacing.md),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _errMsg = '');
                            _loadData();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _current == null
                  ? _buildOpenShiftForm(context, textTheme, biz)
                  : _buildCloseShiftForm(context, textTheme, biz, _current!),
    );
  }

  Widget _buildOpenShiftForm(BuildContext context, TextTheme textTheme, GoldenityBizColors biz) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        child: Form(
          key: _openFormKey,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GoldenityRadius.xxl),
              border: Border.all(color: GoldenityColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(GoldenitySpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: GoldenityColors.warningLight,
                    borderRadius: BorderRadius.circular(GoldenityRadius.xxl),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_open_rounded, size: 40, color: GoldenityColors.warning),
                ),
                const SizedBox(height: GoldenitySpacing.md),
                Text(
                  'Anda BELUM BUKA SHIFT',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: GoldenitySpacing.xs),
                Text(
                  'Masukkan modal awal kas hari ini.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.text2),
                ),
                const SizedBox(height: GoldenitySpacing.xl),
                TextFormField(
                  controller: _openingCashCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      if (newValue.text.isEmpty) {
                        return const TextEditingValue(text: '0', selection: TextSelection.collapsed(offset: 1));
                      }
                      final formatted = _formatCurrencyInput(newValue.text);
                      return TextEditingValue(
                        text: formatted,
                        selection: TextSelection.collapsed(offset: formatted.length),
                      );
                    }),
                  ],
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontFamily: 'RobotoMono',
                    color: biz.dark,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Modal Awal (Opening Cash)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final val = _parseCurrency(v ?? '0');
                    if (val < 0) return 'Tidak boleh negatif';
                    return null;
                  },
                ),
                const SizedBox(height: GoldenitySpacing.xl),
                GoldenityPrimaryButton(
                  label: 'BUKA SHIFT',
                  icon: Icons.play_arrow_rounded,
                  backgroundColor: biz.base,
                  shadow: GoldenityElevation.btnPrimary,
                  height: 48,
                  onPressed: _loading ? null : _openShift,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCloseShiftForm(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, ShiftProfile current) {
    final cashTxCount = _countCashTransactions(current);
    final totalCashIn = _blindModeCashier ? 0 : _sumCashSales(current);
    final totalRefund = _blindModeCashier ? 0 : _sumRefunds(current);
    final expectedCash = _blindModeCashier
        ? 0
        : (current.expectedCashLive ?? current.openingCash + totalCashIn - totalRefund);

    final dur = DateTime.now().difference(current.openedAt);
    final durLabel = '${dur.inHours}j ${dur.inMinutes % 60}m';

    return ListView(
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      children: [
        // ── Banner shift aktif (Figma arch-sleek) ──
        Container(
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.xl),
            border: Border.all(color: GoldenityColors.border),
            boxShadow: GoldenityElevation.card,
          ),
          padding: const EdgeInsets.all(GoldenitySpacing.lg),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GoldenityColors.primaryLight,
                  borderRadius: BorderRadius.circular(GoldenityRadius.full),
                ),
                child: const Text('Shift Aktif',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800, color: GoldenityColors.primary)),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Buka ${DateFormat('HH:mm', 'id_ID').format(current.openedAt)}'
                        '${current.branchName != null ? ' · ${current.branchName}' : ''}',
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${current.cashierName ?? 'Kasir'} · berjalan $durLabel',
                        style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2)),
                  ],
                ),
              ),
              Text(_dateTimeFormatter.format(current.openedAt),
                  style: const TextStyle(
                      fontSize: 11, color: GoldenityColors.muted, fontFamily: 'RobotoMono')),
            ],
          ),
        ),
        const SizedBox(height: GoldenitySpacing.md),
        // ── 3 KPI card ──
        Row(
          children: [
            Expanded(child: _ShiftKpi(label: 'Modal Awal', value: _formatCurrency(current.openingCash))),
            const SizedBox(width: GoldenitySpacing.md),
            Expanded(
                child: _ShiftKpi(
                    label: 'Pemasukan',
                    value: _blindModeCashier ? '••••' : _formatCurrency(totalCashIn))),
            const SizedBox(width: GoldenitySpacing.md),
            Expanded(
                child: _ShiftKpi(
                    label: 'Perkiraan Kas',
                    value: _blindModeCashier ? '••••' : _formatCurrency(expectedCash),
                    accent: GoldenityColors.primary)),
          ],
        ),
        const SizedBox(height: GoldenitySpacing.md),
        // ── Rincian pembayaran ringkas ──
        Container(
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.xl),
            border: Border.all(color: GoldenityColors.border),
            boxShadow: GoldenityElevation.card,
          ),
          padding: const EdgeInsets.all(GoldenitySpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Rincian Shift',
                  style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: GoldenitySpacing.sm),
              _shiftRow('Transaksi tunai', '$cashTxCount transaksi'),
              if (!_blindModeCashier) _shiftRow('Total tunai masuk', _formatCurrency(totalCashIn)),
              if (!_blindModeCashier)
                _shiftRow('Total refund', '- ${_formatCurrency(totalRefund)}',
                    color: GoldenityColors.error),
              const Divider(height: 16, color: GoldenityColors.border),
              _shiftRow('Perkiraan kas di laci',
                  _blindModeCashier ? '••••' : _formatCurrency(expectedCash),
                  bold: true),
            ],
          ),
        ),
        const SizedBox(height: GoldenitySpacing.md),
        Form(
          key: _closeFormKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              border: Border.all(color: GoldenityColors.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: biz.base),
                    const SizedBox(width: GoldenitySpacing.sm),
                    Text(
                      'Tutup Shift & Rekonsiliasi',
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _actualCashCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) {
                              return const TextEditingValue(text: '0', selection: TextSelection.collapsed(offset: 1));
                            }
                            final formatted = _formatCurrencyInput(newValue.text);
                            return TextEditingValue(
                              text: formatted,
                              selection: TextSelection.collapsed(offset: formatted.length),
                            );
                          }),
                        ],
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          fontFamily: 'RobotoMono',
                          color: GoldenityColors.error,
                        ),
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Uang Fisik di Kasir (Actual Cash)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final val = _parseCurrency(v ?? '0');
                          if (val < 0) return 'Tidak boleh negatif';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.md),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (Opsional)',
                    hintText: 'Catatan untuk shift ini, misal: selisih karena receh',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: GoldenitySpacing.lg),
                GoldenityPrimaryButton(
                  label: 'TUTUP SHIFT',
                  icon: Icons.stop_rounded,
                  backgroundColor: GoldenityColors.error,
                  shadow: const [BoxShadow(color: Color(0x4DDC2626), blurRadius: 12, offset: Offset(0, 4))],
                  height: 48,
                  onPressed: _loading ? null : _closeShift,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shiftRow(String label, String value, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: bold ? 13.5 : 12.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    color: GoldenityColors.text2)),
            Text(value,
                style: TextStyle(
                  fontSize: bold ? 14 : 12.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? GoldenityColors.text,
                  fontFamily: 'RobotoMono',
                )),
          ],
        ),
      );
}

class _ShiftKpi extends StatelessWidget {
  const _ShiftKpi({required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) => Container(
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
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.04,
                    color: GoldenityColors.muted)),
            const SizedBox(height: GoldenitySpacing.sm),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'RobotoMono',
                    color: accent ?? GoldenityColors.text)),
          ],
        ),
      );
}

class _ReconRow extends StatelessWidget {
  final String label;
  final String value;
  final TextTheme textTheme;
  final Color? valueColor;
  final bool isBold;

  const _ReconRow({
    required this.label,
    required this.value,
    required this.textTheme,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600)),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(
            fontFamily: 'RobotoMono',
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
