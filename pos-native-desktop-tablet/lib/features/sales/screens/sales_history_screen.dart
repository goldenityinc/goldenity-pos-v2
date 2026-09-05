import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/config/api_constants.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  List<Map<String, dynamic>> _sales = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _errorMessage;
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  final DateFormat _dateFormatter = DateFormat('dd MMM yyyy HH:mm', 'id_ID');

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _loadSales(initial: true));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchQuery.trim().toLowerCase();
    return _sales.where((s) {
      // text search
      if (q.isNotEmpty) {
        final id = s['id']?.toString().toLowerCase() ?? '';
        final ref = s['referenceId']?.toString().toLowerCase() ?? '';
        final cashier = s['cashierName']?.toString().toLowerCase() ?? '';
        final status = s['status']?.toString().toLowerCase() ?? '';
        final orderType = s['orderType']?.toString().toLowerCase() ?? '';
        final totalMatch = _currencyFormatter
            .format(num.tryParse(s['total']?.toString() ?? '0') ?? 0)
            .toLowerCase()
            .contains(q);
        final any = id.contains(q) ||
            ref.contains(q) ||
            cashier.contains(q) ||
            status.contains(q) ||
            orderType.contains(q) ||
            totalMatch;
        if (!any) return false;
      }
      // date filter
      final createdAtRaw = s['createdAt']?.toString();
      if (createdAtRaw != null) {
        final parsed = DateTime.tryParse(createdAtRaw);
        if (parsed != null) {
          final d = DateTime(parsed.year, parsed.month, parsed.day);
          if (_filterStartDate != null) {
            final s2 = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
            if (d.isBefore(s2)) return false;
          }
          if (_filterEndDate != null) {
            final e = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day);
            if (d.isAfter(e)) return false;
          }
        }
      }
      return true;
    }).toList(growable: false);
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialStart = _filterStartDate ?? now.subtract(const Duration(days: 6));
    final initialEnd = _filterEndDate ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 30)),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Terapkan',
    );
    if (picked != null && mounted) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
    }
  }

  Future<void> _loadSales({bool initial = false}) async {
    if (initial && !mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi login tidak ditemukan, silakan login ulang.';
        });
      }
      return;
    }
    try {
      final uri = ApiConstants.salesEndpoint();
      final res = await http.get(
        uri,
        headers: <String, String>{
          'Authorization': session.bearerAuthorizationHeader,
          'Accept': 'application/json',
        },
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final data = body['data'] is Map && body['data']['sales'] is List
            ? (body['data']['sales'] as List)
            : const <dynamic>[];
        if (mounted) {
          setState(() {
            _sales = data
                .map<Map<String, dynamic>>((e) =>
                    e is Map<String, dynamic> ? e : <String, dynamic>{})
                .toList(growable: false);
            _isLoading = false;
          });
        }
      } else {
        String msg = 'Gagal memuat riwayat penjualan (HTTP ${res.statusCode}).';
        try {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          if (body['error'] is String && body['error'].toString().trim().isNotEmpty) {
            msg = body['error'].toString();
          }
        } catch (_) {}
        if (mounted) {
          setState(() {
            _errorMessage = msg;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Gagal terhubung ke server untuk riwayat penjualan: $e';
          _isLoading = false;
        });
      }
    }
  }

  (Color bg, Color fg) _statusColor(String status) {
    switch (status) {
      case 'VOIDED':
        return (GoldenityColors.errorLight, GoldenityColors.error);
      case 'PARTIALLY_REFUNDED':
        return (GoldenityColors.warningLight, GoldenityColors.warning);
      case 'REFUNDED':
        return (GoldenityColors.surface2, GoldenityColors.muted);
      case 'COMPLETED':
      default:
        return (GoldenityColors.successLight, GoldenityColors.success);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'VOIDED':
        return 'DIBATALKAN';
      case 'PARTIALLY_REFUNDED':
        return 'DANA SEBAGIAN';
      case 'REFUNDED':
        return 'PENGEMBALIAN';
      case 'COMPLETED':
      default:
        return 'SELESAI';
    }
  }

  bool _canBeVoided(String status) => status == 'COMPLETED' || status == 'PARTIALLY_REFUNDED';

  Future<void> _showSaleDetail(Map<String, dynamic> sale) async {
    final textTheme = Theme.of(context).textTheme;
    final biz = Theme.of(context).extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    final id = sale['id']?.toString() ?? '-';
    final refId = sale['referenceId']?.toString();
    final statusRaw = sale['status']?.toString() ?? 'COMPLETED';
    final (chipBg, chipFg) = _statusColor(statusRaw);
    final createdAtRaw = sale['createdAt']?.toString();
    final createdAt = createdAtRaw != null && DateTime.tryParse(createdAtRaw) != null
        ? DateTime.tryParse(createdAtRaw)!
        : DateTime.now();
    final cashierName = sale['cashierName']?.toString() ?? 'Kasir';
    final orderTypeLabel = sale['orderType']?.toString() == 'TAKE_AWAY'
        ? 'Bawa Pulang'
        : 'Makan di Tempat';
    final paymentMethod = sale['paymentMethod']?.toString() ?? 'CASH';
    final paymentLabel = _paymentMethodLabel(paymentMethod);
    final paymentRef = sale['paymentReferenceNumber']?.toString();
    final cashReceived = num.tryParse(sale['cashReceived']?.toString() ?? '0') ?? 0;
    final cashChange = num.tryParse(sale['cashChange']?.toString() ?? '0') ?? 0;

    final subtotal = num.tryParse(sale['subtotal']?.toString() ?? '0') ?? 0;
    final discountAmount = num.tryParse(sale['discountAmount']?.toString() ?? '0') ?? 0;
    final discountPercent = num.tryParse(sale['discountPercent']?.toString() ?? '0') ?? 0;
    final taxAmount = num.tryParse(sale['taxAmount']?.toString() ?? '0') ?? 0;
    final serviceChargeAmount = num.tryParse(sale['serviceChargeAmount']?.toString() ?? '0') ?? 0;
    final total = num.tryParse(sale['total']?.toString() ?? '0') ?? 0;

    final itemsRaw = sale['items'];
    final List<Map<String, dynamic>> items = itemsRaw is List
        ? itemsRaw.whereType<Map<String, dynamic>>().toList(growable: false)
        : const [];

    final canVoid = _canBeVoided(statusRaw);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xxxl)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: GoldenitySpacing.xl),
        child: SizedBox(
          width: 640,
          child: Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Detail Transaksi',
                                  style: textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(width: GoldenitySpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: GoldenitySpacing.sm, vertical: 2),
                                decoration: BoxDecoration(
                                  color: chipBg,
                                  borderRadius: BorderRadius.circular(GoldenityRadius.full),
                                ),
                                child: Text(
                                  _statusLabel(statusRaw),
                                  style: TextStyle(
                                    fontFamily: GoldenityTypography.fontFamilySans,
                                    color: chipFg,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '#$id · ${_dateFormatter.format(createdAt)}',
                            style: textTheme.bodySmall?.copyWith(
                                color: GoldenityColors.text2, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '$cashierName · $orderTypeLabel${refId != null && refId.trim().isNotEmpty ? ' · Ref: $refId' : ''}',
                            style: textTheme.bodySmall?.copyWith(
                                color: GoldenityColors.text2, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.lg),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: GoldenityColors.surface,
                      borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                      border: Border.all(color: GoldenityColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              GoldenitySpacing.md, GoldenitySpacing.sm, GoldenitySpacing.md, 0),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text('Item',
                                    style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w800, color: GoldenityColors.text2)),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text('Qty',
                                    textAlign: TextAlign.center,
                                    style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w800, color: GoldenityColors.text2)),
                              ),
                              SizedBox(
                                width: 110,
                                child: Text('Subtotal',
                                    textAlign: TextAlign.right,
                                    style: textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.w800, color: GoldenityColors.text2)),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: GoldenityColors.border, thickness: 0.8),
                        Flexible(
                          fit: FlexFit.loose,
                          child: items.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(GoldenitySpacing.md),
                                  child: Text('(tidak ada detail item)',
                                      style: TextStyle(color: GoldenityColors.muted)),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: GoldenitySpacing.md, vertical: 2),
                                  itemCount: items.length,
                                  separatorBuilder: (_, __) => const Divider(
                                      height: 1, color: GoldenityColors.border, thickness: 0.4),
                                  itemBuilder: (_, idx) {
                                    final it = items[idx];
                                    final name = it['productName']?.toString() ?? 'Produk';
                                    final variantName = it['variantName']?.toString();
                                    final note = it['note']?.toString();
                                    final qty = num.tryParse(it['qty']?.toString() ?? '0') ?? 0;
                                    final unitPrice = num.tryParse(it['unitPrice']?.toString() ?? '0') ?? 0;
                                    final lineTotal = num.tryParse(it['lineTotal']?.toString() ?? '0') ?? 0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: GoldenitySpacing.sm),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(name,
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: textTheme.bodySmall?.copyWith(
                                                        fontWeight: FontWeight.w700,
                                                        color: GoldenityColors.text)),
                                                if (variantName != null &&
                                                    variantName.trim().isNotEmpty)
                                                  Text('  Var: $variantName',
                                                      style: textTheme.labelSmall?.copyWith(
                                                          color: GoldenityColors.text2)),
                                                if (note != null && note.trim().isNotEmpty)
                                                  Text('  Note: $note',
                                                      style: textTheme.labelSmall?.copyWith(
                                                          color: GoldenityColors.muted)),
                                                Text(
                                                    '  @ ${_currencyFormatter.format(unitPrice)}',
                                                    style: textTheme.labelSmall?.copyWith(
                                                        color: GoldenityColors.text2,
                                                        fontFamily: GoldenityTypography
                                                            .fontFamilyMono)),
                                              ],
                                            ),
                                          ),
                                          SizedBox(
                                            width: 56,
                                            child: Text('$qty',
                                                textAlign: TextAlign.center,
                                                style: textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    fontFamily: GoldenityTypography
                                                        .fontFamilyMono)),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text(_currencyFormatter.format(lineTotal),
                                                textAlign: TextAlign.right,
                                                style: textTheme.bodySmall?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    fontFamily: GoldenityTypography
                                                        .fontFamilyMono,
                                                    color: biz.dark)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: GoldenitySpacing.md),
                Container(
                  padding: const EdgeInsets.all(GoldenitySpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                    border: Border.all(color: GoldenityColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryRow(
                          context, 'Subtotal', _currencyFormatter.format(subtotal)),
                      if (discountAmount > 0)
                        _buildSummaryRow(
                          context,
                          discountPercent > 0
                              ? 'Diskon (${discountPercent.toStringAsFixed(0)}%)'
                              : 'Diskon',
                          '- ${_currencyFormatter.format(discountAmount)}',
                          fgColor: GoldenityColors.error,
                        ),
                      if (serviceChargeAmount > 0)
                        _buildSummaryRow(context, 'Service Charge',
                            '+ ${_currencyFormatter.format(serviceChargeAmount)}'),
                      if (taxAmount > 0)
                        _buildSummaryRow(
                            context, 'Pajak', '+ ${_currencyFormatter.format(taxAmount)}'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: GoldenitySpacing.xs),
                        child: Divider(height: 1, color: GoldenityColors.border2, thickness: 1),
                      ),
                      _buildSummaryRow(context, 'TOTAL', _currencyFormatter.format(total),
                          isBold: true, fgColor: biz.dark, totalMode: true),
                    ],
                  ),
                ),
                const SizedBox(height: GoldenitySpacing.md),
                Container(
                  padding: const EdgeInsets.all(GoldenitySpacing.md),
                  decoration: BoxDecoration(
                    color: GoldenityColors.surface2,
                    borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSummaryRow(context, 'Metode Bayar', paymentLabel),
                      if (paymentRef != null && paymentRef.trim().isNotEmpty)
                        _buildSummaryRow(context, 'Ref. Pembayaran', paymentRef),
                      if (paymentMethod == 'CASH' && cashReceived > 0) ...[
                        _buildSummaryRow(context, 'Uang Diterima',
                            _currencyFormatter.format(cashReceived)),
                        _buildSummaryRow(
                          context,
                          'Kembalian',
                          cashChange > 0 ? _currencyFormatter.format(cashChange) : '-',
                          fgColor: GoldenityColors.success,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: GoldenitySpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text('Tutup',
                            style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
                        ),
                      ),
                    ),
                    if (canVoid) ...[
                      const SizedBox(width: GoldenitySpacing.sm),
                      Expanded(
                        child: GoldenityPrimaryButton(
                          label: 'Batalkan (Void)',
                          icon: Icons.block_rounded,
                          backgroundColor: GoldenityColors.error,
                          shadow: const [
                            BoxShadow(color: Color(0x4DDC2626), blurRadius: 12, offset: Offset(0, 4))
                          ],
                          height: 44,
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _openVoidDialog(sale);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value,
      {Color? fgColor, bool isBold = false, bool totalMode = false}) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: textTheme.labelSmall?.copyWith(
                      fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                      color: GoldenityColors.text2,
                      fontSize: totalMode ? 14 : 12))),
          Text(value,
              style: textTheme.labelSmall?.copyWith(
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
                  color: fgColor ?? GoldenityColors.text,
                  fontSize: totalMode ? 16 : 13,
                  fontFamily: GoldenityTypography.fontFamilyMono)),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'QRIS':
        return 'QRIS';
      case 'CREDIT_CARD':
      case 'DEBIT_CARD':
        return 'Kartu';
      case 'CASH':
      default:
        return 'Tunai';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final biz = Theme.of(context).extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? GoldenityColors.error : biz.base,
        duration: Duration(seconds: isError ? 4 : 2),
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.lg)),
        margin: const EdgeInsets.all(GoldenitySpacing.md),
      ),
    );
  }

  Future<void> _openVoidDialog(Map<String, dynamic> sale) async {
    final statusRaw = sale['status']?.toString() ?? '';
    if (!_canBeVoided(statusRaw)) {
      _showSnackBar(
        'Transaksi ini status ${_statusLabel(statusRaw)} — tidak dapat dibatalkan (void). Hanya status SELESAI / DANA SEBAGIAN yang boleh dibatalkan.',
        isError: true,
      );
      return;
    }
    final result = await showDialog<_VoidDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VoidConfirmDialog(
        saleId: sale['id']?.toString() ?? '',
        orderLabel: '#${sale['id'] ?? sale['referenceId'] ?? '-'}',
        total: _currencyFormatter.format(num.tryParse(sale['total']?.toString() ?? '0') ?? 0),
      ),
    );
    if (result == null || !result.confirmed) return;
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      _showSnackBar('Sesi login tidak valid untuk membatalkan transaksi.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final saleIdStr = sale['id']?.toString() ?? '';
      final uri = ApiConstants.saleVoidEndpoint(saleIdStr);
      final body = <String, dynamic>{
        'voidReason': result.reason.trim(),
        'refundedAmount': result.refundFull
            ? null
            : num.tryParse(sale['total']?.toString() ?? '0')?.toDouble(),
      };
      final res = await http.patch(
        uri,
        headers: <String, String>{
          'Authorization': session.bearerAuthorizationHeader,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        _showSnackBar('Transaksi berhasil dibatalkan. Alasan: ${result.reason.trim()}');
        await _loadSales();
      } else {
        String msg = 'Gagal membatalkan transaksi (HTTP ${res.statusCode}).';
        try {
          final parsed = jsonDecode(res.body) as Map<String, dynamic>;
          if (parsed['error'] is String &&
              parsed['error'].toString().trim().isNotEmpty) {
            msg = parsed['error'].toString();
          }
        } catch (_) {}
        _showSnackBar(msg, isError: true);
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      _showSnackBar('Gagal membatalkan: $e', isError: true);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final biz = Theme.of(context).extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final filtered = _filtered;
    final dateLabel = (_filterStartDate != null || _filterEndDate != null)
        ? '${_filterStartDate != null ? DateFormat('dd/MM/yyyy', 'id_ID').format(_filterStartDate!) : 'Awal'} — ${_filterEndDate != null ? DateFormat('dd/MM/yyyy', 'id_ID').format(_filterEndDate!) : 'Sekarang'}'
        : 'Semua periode';
    final hasFilter = _filterStartDate != null || _filterEndDate != null || _searchQuery.isNotEmpty;

    num totalOmzet = 0;
    int transaksiCount = 0;
    for (final s in filtered) {
      final t = num.tryParse(s['total']?.toString() ?? '0') ?? 0;
      totalOmzet += t;
      transaksiCount += 1;
    }

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Riwayat Penjualan', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              '$transaksiCount transaksi · Omzet: ${_currencyFormatter.format(totalOmzet)} · $dateLabel',
              style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: biz.base,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _isLoading ? null : () => _loadSales(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(145),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GoldenitySpacing.lg,
                  0,
                  GoldenitySpacing.lg,
                  GoldenitySpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: 'Cari ID transaksi / kasir / status / nomimal...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: GoldenitySpacing.md,
                            vertical: GoldenitySpacing.md,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GoldenityRadius.md),
                            borderSide: const BorderSide(color: GoldenityColors.border, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(GoldenityRadius.md),
                            borderSide: BorderSide(color: biz.base, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: GoldenitySpacing.sm),
                    OutlinedButton.icon(
                      onPressed: _pickDateRange,
                      icon: const Icon(Icons.date_range_rounded, size: 18),
                      label: Text(
                        _filterStartDate == null && _filterEndDate == null ? 'Pilih Tanggal' : 'Ganti Tanggal',
                        style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                      ),
                    ),
                    if (hasFilter) ...[
                      const SizedBox(width: GoldenitySpacing.xs),
                      IconButton.filledTonal(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                            _filterStartDate = null;
                            _filterEndDate = null;
                          });
                        },
                        icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                        tooltip: 'Hapus filter',
                        style: IconButton.styleFrom(
                          backgroundColor: GoldenityColors.surface2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.md)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: GoldenitySpacing.lg),
                child: Row(
                  children: [
                    Expanded(child: _HeaderChip(label: 'No. Transaksi')),
                    SizedBox(width: GoldenitySpacing.sm),
                    Expanded(flex: 2, child: _HeaderChip(label: 'Info Kasir & Waktu')),
                    SizedBox(width: GoldenitySpacing.sm),
                    SizedBox(width: 140, child: _HeaderChip(label: 'Total')),
                  ],
                ),
              ),
              const SizedBox(height: GoldenitySpacing.sm),
              const Divider(height: 1, color: GoldenityColors.border2, thickness: 1),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSales(),
        color: biz.base,
        child: _isLoading && _sales.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null && _sales.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(GoldenitySpacing.xl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.error_outline, color: GoldenityColors.error, size: 48),
                          const SizedBox(height: GoldenitySpacing.md),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(color: GoldenityColors.text2),
                          ),
                          const SizedBox(height: GoldenitySpacing.md),
                          GoldenityPrimaryButton(
                            onPressed: () => _loadSales(),
                            label: 'Coba Lagi',
                          ),
                        ],
                      ),
                    ),
                  )
                : _sales.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(GoldenitySpacing.xl),
                        children: <Widget>[
                          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                          const Icon(Icons.receipt_long, size: 56, color: GoldenityColors.muted),
                          const SizedBox(height: GoldenitySpacing.md),
                          Text(
                            'Belum ada transaksi penjualan.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyLarge?.copyWith(color: GoldenityColors.muted),
                          ),
                        ],
                      )
                    : filtered.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.all(GoldenitySpacing.xl),
                            children: [
                              SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                              const Icon(Icons.search_off_rounded, size: 56, color: GoldenityColors.muted),
                              const SizedBox(height: GoldenitySpacing.md),
                              Text(
                                'Tidak ada transaksi yang cocok dengan filter.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodyLarge?.copyWith(color: GoldenityColors.muted),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Coba kata kunci lain atau hapus filter tanggal / pencarian.',
                                textAlign: TextAlign.center,
                                style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              GoldenitySpacing.lg,
                              GoldenitySpacing.md,
                              GoldenitySpacing.lg,
                              GoldenitySpacing.xl,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (ctx, i) {
                              final sale = filtered[i];
                              final id = sale['id']?.toString() ?? '-';
                              final refId = sale['referenceId']?.toString();
                              final totalRaw = num.tryParse(sale['total']?.toString() ?? '0') ?? 0;
                              final createdAtRaw = sale['createdAt']?.toString();
                              DateTime createdAt = DateTime.now();
                              if (createdAtRaw != null) {
                                final tryParse = DateTime.tryParse(createdAtRaw);
                                if (tryParse != null) createdAt = tryParse;
                              }
                              final statusRaw = sale['status']?.toString() ?? 'COMPLETED';
                              final cashierName = sale['cashierName']?.toString() ?? 'Kasir';
                              final orderType = sale['orderType']?.toString() == 'TAKE_AWAY'
                                  ? 'Bawa Pulang'
                                  : 'Makan di Tempat';
                              final voided = statusRaw == 'VOIDED';
                              final (chipBg, chipFg) = _statusColor(statusRaw);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: GoldenitySpacing.md),
                                child: Material(
                                  color: GoldenityColors.surface,
                                  borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                                  clipBehavior: Clip.antiAlias,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _showSaleDetail(sale),
                                    borderRadius: BorderRadius.circular(GoldenityRadius.xl),
                                    child: Padding(
                                      padding: const EdgeInsets.all(GoldenitySpacing.lg),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: <Widget>[
                                                Row(
                                                  children: <Widget>[
                                                    Text(
                                                      '#$id',
                                                      style: textTheme.titleMedium?.copyWith(
                                                        color: voided ? GoldenityColors.muted : GoldenityColors.text,
                                                        decoration: voided ? TextDecoration.lineThrough : null,
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(width: GoldenitySpacing.sm),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: GoldenitySpacing.sm,
                                                        vertical: 2,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: chipBg,
                                                        borderRadius: BorderRadius.circular(GoldenityRadius.full),
                                                      ),
                                                      child: Text(
                                                        _statusLabel(statusRaw),
                                                        style: TextStyle(
                                                          fontFamily: GoldenityTypography.fontFamilySans,
                                                          color: chipFg,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w700,
                                                          height: 1.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: GoldenitySpacing.xs),
                                                Text(
                                                  '${_dateFormatter.format(createdAt)} · $cashierName · $orderType',
                                                  style: textTheme.bodyLarge?.copyWith(
                                                    color: GoldenityColors.text2,
                                                  ),
                                                ),
                                                if (refId != null && refId.trim().isNotEmpty)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: GoldenitySpacing.xs),
                                                    child: Text(
                                                      'Ref: $refId',
                                                      style: const TextStyle(
                                                        fontFamily: GoldenityTypography.fontFamilySans,
                                                        color: GoldenityColors.muted,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                if (voided && sale['voidReason']?.toString().trim().isNotEmpty == true)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: GoldenitySpacing.sm),
                                                    child: Text(
                                                      'Alasan batal: ${sale['voidReason']}',
                                                      style: textTheme.bodyLarge?.copyWith(
                                                        color: GoldenityColors.error,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: GoldenitySpacing.md),
                                          Text(
                                            _currencyFormatter.format(totalRaw),
                                            textAlign: TextAlign.right,
                                            style: textTheme.titleLarge?.copyWith(
                                              color: voided ? GoldenityColors.muted : biz.base,
                                              decoration: voided ? TextDecoration.lineThrough : null,
                                              fontWeight: FontWeight.w800,
                                              fontFamily: GoldenityTypography.fontFamilyMono,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm, vertical: 8),
      decoration: BoxDecoration(
        color: GoldenityColors.surface2,
        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: GoldenityColors.text2,
        ),
      ),
    );
  }
}

class _VoidDialogResult {
  final bool confirmed;
  final String reason;
  final bool refundFull;
  const _VoidDialogResult({required this.confirmed, required this.reason, required this.refundFull});
}

class _VoidConfirmDialog extends StatefulWidget {
  final String saleId;
  final String orderLabel;
  final String total;
  const _VoidConfirmDialog({
    required this.saleId,
    required this.orderLabel,
    required this.total,
  });

  @override
  State<_VoidConfirmDialog> createState() => _VoidConfirmDialogState();
}

class _VoidConfirmDialogState extends State<_VoidConfirmDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
      insetPadding: const EdgeInsets.all(GoldenitySpacing.xl),
      child: Padding(
        padding: const EdgeInsets.all(GoldenitySpacing.xl),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Icon(Icons.warning_amber, color: GoldenityColors.error, size: 28),
                    const SizedBox(width: GoldenitySpacing.md),
                    Expanded(
                      child: Text(
                        'Batalkan Transaksi ${widget.orderLabel}',
                        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GoldenitySpacing.md),
                Text(
                  'Tindakan ini akan mengubah status transaksi menjadi DIBATALKAN dan nominal pengembalian (${widget.total}) akan dicatat sebagai refundedAmount. Pembatalan tidak dapat dikembalikan.',
                  style: textTheme.bodyLarge?.copyWith(color: GoldenityColors.text2),
                ),
                const SizedBox(height: GoldenitySpacing.lg),
                TextFormField(
                  controller: _reasonCtrl,
                  decoration: InputDecoration(
                    labelText: 'Alasan Pembatalan *',
                    hintText: 'Contoh: salah input item / pelanggan batal order',
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: GoldenityColors.border),
                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: GoldenityColors.primary, width: 2),
                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: GoldenityColors.error, width: 2),
                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: GoldenityColors.error, width: 2),
                      borderRadius: BorderRadius.circular(GoldenityRadius.lg),
                    ),
                    contentPadding: const EdgeInsets.all(GoldenitySpacing.md),
                  ),
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 4,
                  textInputAction: TextInputAction.done,
                  validator: (val) {
                    final trimmed = (val ?? '').trim();
                    if (trimmed.isEmpty) {
                      return 'Alasan pembatalan WAJIB diisi (minimal 3 karakter).';
                    }
                    if (trimmed.length < 3) {
                      return 'Alasan pembatalan minimal 3 karakter. Misal: salah input atau batal pesanan.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: GoldenitySpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Batal',
                        style: TextStyle(
                          fontFamily: GoldenityTypography.fontFamilySans,
                          color: GoldenityColors.text2,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: GoldenitySpacing.md),
                    GoldenityPrimaryButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              if (!(_formKey.currentState?.validate() ?? false)) return;
                              setState(() => _isSubmitting = true);
                              Navigator.of(context).pop(
                                _VoidDialogResult(
                                  confirmed: true,
                                  reason: _reasonCtrl.text,
                                  refundFull: true,
                                ),
                              );
                            },
                      label: 'Konfirmasi Batalkan',
                      backgroundColor: GoldenityColors.error,
                      foregroundColor: GoldenityColors.surface,
                      shadow: GoldenityElevation.btnSuccess,
                      icon: Icons.cancel_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
