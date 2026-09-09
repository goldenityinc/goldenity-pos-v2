import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../../core/config/api_constants.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/goldenity_modal.dart';
import '../../../shared/widgets/goldenity_page_header.dart';
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

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  // Tab status: '' = semua, 'DONE' = SELESAI/DANA, 'VOIDED', 'PENDING'
  String _statusFilter = '';

  bool _matchStatusFilter(String statusRaw) {
    switch (_statusFilter) {
      case '':
        return true;
      case 'VOIDED':
        return statusRaw == 'VOIDED';
      case 'PENDING':
        return statusRaw == 'PENDING' || statusRaw == 'PARTIAL';
      case 'DONE':
        return statusRaw == 'COMPLETED' || statusRaw == 'DONE' || statusRaw == 'PAID';
      default:
        return true;
    }
  }

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _loadSales(initial: true));
    // Segarkan berkala supaya penjualan baru (mis. web order yang diterima /
    // dibayar) langsung muncul tanpa perlu keluar-masuk halaman.
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 20), (_) => _loadSales(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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
      // status tab filter
      if (!_matchStatusFilter(s['status']?.toString() ?? 'COMPLETED')) {
        return false;
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

  Future<void> _loadSales({bool initial = false, bool silent = false}) async {
    if (initial && !mounted) return;
    if (!mounted) return;
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    final session = ref.read(currentSessionProvider);
    if (session == null) {
      if (mounted && !silent) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi login tidak ditemukan, silakan login ulang.';
        });
      }
      return;
    }
    try {
      // POS di-scope ke cabang login (slice "semua cabang" hanya di Back Office).
      final branchId = session.selectedBranchId ?? session.user.branchId;
      final uri = ApiConstants.salesEndpoint(
        branchId != null && branchId.isNotEmpty ? {'branchId': branchId} : null,
      );
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
    final id = sale['id']?.toString() ?? '-';
    final statusRaw = sale['status']?.toString() ?? 'COMPLETED';
    final (chipBg, chipFg) = _statusColor(statusRaw);
    final createdAtRaw = sale['createdAt']?.toString();
    final createdAt = createdAtRaw != null && DateTime.tryParse(createdAtRaw) != null
        ? DateTime.tryParse(createdAtRaw)!
        : DateTime.now();
    final cashierName = sale['cashierName']?.toString() ?? 'Kasir';
    final paymentMethod = sale['paymentMethod']?.toString() ?? 'CASH';
    final paymentLabel = _paymentMethodLabel(paymentMethod);

    final subtotal = num.tryParse(sale['subtotal']?.toString() ?? '0') ?? 0;
    final discountAmount = num.tryParse(sale['discountAmount']?.toString() ?? '0') ?? 0;
    final taxAmount = num.tryParse(sale['taxAmount']?.toString() ?? '0') ?? 0;
    final serviceChargeAmount = num.tryParse(sale['serviceChargeAmount']?.toString() ?? '0') ?? 0;
    final total = num.tryParse(sale['total']?.toString() ?? '0') ?? 0;

    final itemsRaw = sale['items'];
    final List<Map<String, dynamic>> items = itemsRaw is List
        ? itemsRaw.whereType<Map<String, dynamic>>().toList(growable: false)
        : const [];

    final canVoid = _canBeVoided(statusRaw);
    final cashierNote = sale['cashierNote']?.toString() ?? '';
    final proofUrl = sale['paymentProofUrl']?.toString();
    final tableLabel = sale['tableName']?.toString() ??
        sale['tableLabel']?.toString() ??
        (sale['orderType']?.toString() == 'TAKE_AWAY' ? 'Bawa Pulang' : 'Umum');

    await _showSaleDrawer(
      sale: sale,
      id: id,
      createdAt: createdAt,
      cashierName: cashierName,
      tableLabel: tableLabel,
      statusRaw: statusRaw,
      chipBg: chipBg,
      chipFg: chipFg,
      paymentMethod: paymentMethod,
      paymentLabel: paymentLabel,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      serviceChargeAmount: serviceChargeAmount,
      total: total,
      cashierNote: cashierNote,
      proofUrl: proofUrl,
      canVoid: canVoid,
    );
  }

  Future<void> _showSaleDrawer({
    required Map<String, dynamic> sale,
    required String id,
    required DateTime createdAt,
    required String cashierName,
    required String tableLabel,
    required String statusRaw,
    required Color chipBg,
    required Color chipFg,
    required String paymentMethod,
    required String paymentLabel,
    required List<Map<String, dynamic>> items,
    required num subtotal,
    required num taxAmount,
    required num discountAmount,
    required num serviceChargeAmount,
    required num total,
    required String cashierNote,
    required String? proofUrl,
    required bool canVoid,
  }) async {
    final (mBg, mFg) = _paymentChipColor(paymentMethod);
    await showGoldenityDetailDrawer<void>(
      context: context,
      id: '#$id',
      subtitle: DateFormat('d MMM yyyy • HH:mm', 'id_ID').format(createdAt),
      actions: [
        GoldenityDrawerAction(
          label: 'Cetak Ulang',
          icon: Icons.print_rounded,
          onTap: () {
            Navigator.of(context).maybePop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cetak ulang struk dikirim ke printer.')),
            );
          },
        ),
        if (canVoid)
          GoldenityDrawerAction(
            label: 'Void Transaksi',
            icon: Icons.block_rounded,
            color: GoldenityColors.error,
            borderColor: const Color(0xFFFECACA),
            onTap: () async {
              Navigator.of(context).maybePop();
              await _openVoidDialog(sale);
            },
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Kasir: $cashierName  ·  $tableLabel',
              style: const TextStyle(fontSize: 12, color: GoldenityColors.text2)),
          const SizedBox(height: 14),
          // item table
          const Row(
            children: [
              Expanded(child: _ColLabel('Item')),
              SizedBox(width: 34, child: _ColLabel('Qty', center: true)),
              SizedBox(width: 84, child: _ColLabel('Subtotal', end: true)),
            ],
          ),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('(tidak ada detail item)',
                style: TextStyle(fontSize: 12, color: GoldenityColors.muted))
          else
            for (final it in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(it['productName']?.toString() ?? 'Produk',
                          style: const TextStyle(fontSize: 12.5, color: GoldenityColors.text)),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text('×${num.tryParse(it['qty']?.toString() ?? '0') ?? 0}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 12,
                              color: GoldenityColors.text2,
                              fontFamily: GoldenityTypography.fontFamilyMono)),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                          _currencyFormatter
                              .format(num.tryParse(it['lineTotal']?.toString() ?? '0') ?? 0),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GoldenityColors.text,
                              fontFamily: GoldenityTypography.fontFamilyMono)),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: GoldenityColors.border),
          const SizedBox(height: 10),
          _drawerAmountRow('Subtotal', _currencyFormatter.format(subtotal)),
          if (discountAmount > 0)
            _drawerAmountRow('Diskon', '- ${_currencyFormatter.format(discountAmount)}'),
          if (serviceChargeAmount > 0)
            _drawerAmountRow('Service Charge', _currencyFormatter.format(serviceChargeAmount)),
          if (taxAmount > 0)
            _drawerAmountRow('PPN', _currencyFormatter.format(taxAmount)),
          const SizedBox(height: 6),
          _drawerAmountRow('Total', _currencyFormatter.format(total), bold: true),
          const SizedBox(height: 14),
          Row(
            children: [
              _pill(paymentLabel, mBg, mFg),
              const SizedBox(width: 6),
              _pill(_statusLabel(statusRaw), chipBg, chipFg),
            ],
          ),
          const SizedBox(height: 18),
          const Text('CATATAN KASIR',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.06, color: GoldenityColors.muted)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _editCashierNote(sale, cashierNote),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: GoldenityColors.surface2,
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
                border: Border.all(
                    color: GoldenityColors.border, style: BorderStyle.solid),
              ),
              child: Text(
                cashierNote.trim().isEmpty
                    ? 'Belum ada catatan — klik untuk menambah'
                    : cashierNote,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: cashierNote.trim().isEmpty ? FontStyle.italic : FontStyle.normal,
                  color: cashierNote.trim().isEmpty
                      ? GoldenityColors.disabled
                      : GoldenityColors.text,
                ),
              ),
            ),
          ),
          if (proofUrl != null && proofUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('BUKTI TRANSFER (QRIS)',
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.06, color: GoldenityColors.muted)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _viewProof(proofUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
                child: Image.network(
                  proofUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 60,
                    alignment: Alignment.center,
                    color: GoldenityColors.surface2,
                    child: const Text('Gagal memuat bukti',
                        style: TextStyle(fontSize: 12, color: GoldenityColors.muted)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _drawerAmountRow(String label, String value, {bool bold = false}) {
    final w = bold ? FontWeight.w800 : FontWeight.w500;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: bold ? 14 : 12.5,
                  fontWeight: w,
                  color: bold ? GoldenityColors.text : GoldenityColors.text2)),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 14 : 12.5,
                fontWeight: w,
                color: GoldenityColors.text,
                fontFamily: GoldenityTypography.fontFamilyMono,
              )),
        ],
      ),
    );
  }

  Widget _pill(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      );

  (Color, Color) _paymentChipColor(String m) {
    switch (m.toUpperCase()) {
      case 'QRIS':
        return (const Color(0xFFF5F3FF), const Color(0xFF7C3AED));
      case 'CREDIT_CARD':
      case 'CARD':
        return (GoldenityColors.primaryLight, GoldenityColors.primary);
      default:
        return (GoldenityColors.successLight, GoldenityColors.success);
    }
  }

  Future<void> _viewProof(String url) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _editCashierNote(Map<String, dynamic> sale, String current) async {
    final ctrl = TextEditingController(text: current);
    final saved = await showGoldenityDialog<bool>(
      context: context,
      title: 'Catatan Kasir',
      subtitle: '#${sale['id']}',
      child: GoldenityModalField(
        label: 'Catatan',
        controller: ctrl,
        hint: 'mis. Pelanggan minta struk ulang, koreksi item…',
        autofocus: true,
        maxLines: 3,
      ),
      onPrimary: () async {
        final token = ref.read(authNotifierProvider.notifier).session?.token;
        if (token == null) return null;
        try {
          final resp = await http.patch(
            Uri.parse('${ApiConstants.saleByIdEndpoint(sale['id'].toString())}/note'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'note': ctrl.text.trim()}),
          );
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            sale['cashierNote'] = ctrl.text.trim();
            await _loadSales();
            return true;
          }
        } catch (_) {}
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                backgroundColor: GoldenityColors.error, content: Text('Gagal menyimpan catatan')),
          );
        }
        return null;
      },
    );
    if (saved == true && mounted) {
      Navigator.of(context).maybePop(); // tutup drawer supaya buka ulang dgn data baru
    }
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
    final reasonCtrl = TextEditingController();
    bool refundFull = true;
    final confirmed = await showGoldenityDialog<bool>(
      context: context,
      title: 'Batalkan Transaksi',
      subtitle:
          '#${sale['id'] ?? sale['referenceId'] ?? '-'} · ${_currencyFormatter.format(num.tryParse(sale['total']?.toString() ?? '0') ?? 0)}',
      primaryLabel: 'Ya, Batalkan',
      primaryColor: GoldenityColors.error,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Transaksi yang dibatalkan (void) akan mengembalikan stok & tidak '
              'bisa diaktifkan lagi. Wajib isi alasan.',
              style: TextStyle(fontSize: 12.5, color: GoldenityColors.text2, height: 1.4),
            ),
            const SizedBox(height: 14),
            GoldenityModalField(
                label: 'Alasan pembatalan', controller: reasonCtrl, hint: 'mis. salah input item', autofocus: true),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setLocal(() => refundFull = !refundFull),
              child: Row(
                children: [
                  Checkbox(
                    value: refundFull,
                    onChanged: (v) => setLocal(() => refundFull = v ?? true),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Expanded(
                    child: Text('Refund penuh (kembalikan seluruh nilai transaksi)',
                        style: TextStyle(fontSize: 12.5, color: GoldenityColors.text2)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      onPrimary: () async {
        if (reasonCtrl.text.trim().length < 3) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                backgroundColor: GoldenityColors.error,
                content: Text('Alasan minimal 3 karakter')));
          }
          return null;
        }
        return true;
      },
    );
    if (confirmed != true) return;
    final result = _VoidDialogResult(
      confirmed: true,
      reason: reasonCtrl.text.trim(),
      refundFull: refundFull,
    );
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
        title: GoldenityPageHeader(
          title: 'Riwayat Penjualan',
          subtitle:
              '$transaksiCount transaksi · Omzet: ${_currencyFormatter.format(totalOmzet)} · $dateLabel',
          dense: true,
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
          preferredSize: const Size.fromHeight(150),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  GoldenitySpacing.lg,
                  GoldenitySpacing.xs,
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
              // ── Filter status tabs (Figma: Semua / Lunas / Void / Pending) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(GoldenitySpacing.lg, 0, GoldenitySpacing.lg, GoldenitySpacing.sm),
                child: Row(
                  children: [
                    for (final t in <(String, String)>[
                      ('', 'Semua'),
                      ('DONE', 'Selesai'),
                      ('VOIDED', 'Void'),
                      ('PENDING', 'Pending'),
                    ]) ...[
                      _StatusTab(
                        label: t.$2,
                        count: _sales.where((s) {
                          final st = s['status']?.toString() ?? 'COMPLETED';
                          return switch (t.$1) {
                            '' => true,
                            'VOIDED' => st == 'VOIDED',
                            'PENDING' => st == 'PENDING' || st == 'PARTIAL',
                            _ => st == 'COMPLETED' || st == 'DONE' || st == 'PAID',
                          };
                        }).length,
                        active: _statusFilter == t.$1,
                        onTap: () => setState(() => _statusFilter = t.$1),
                      ),
                      const SizedBox(width: GoldenitySpacing.xs),
                    ],
                  ],
                ),
              ),
              // ── Table header ──
              Container(
                color: GoldenityColors.surface2,
                padding: const EdgeInsets.symmetric(
                    horizontal: GoldenitySpacing.lg, vertical: GoldenitySpacing.sm),
                child: const Row(
                  children: [
                    SizedBox(width: 64, child: _ColLabel('ID')),
                    SizedBox(width: 108, child: _ColLabel('WAKTU')),
                    Expanded(child: _ColLabel('KASIR / TIPE')),
                    SizedBox(width: 120, child: _ColLabel('TOTAL', end: true)),
                    SizedBox(width: 92, child: _ColLabel('STATUS', center: true)),
                    SizedBox(width: 56),
                  ],
                ),
              ),
              const Divider(height: 1, color: GoldenityColors.border, thickness: 1),
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
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, color: GoldenityColors.border),
                            itemBuilder: (ctx, i) {
                              final sale = filtered[i];
                              final id = sale['id']?.toString() ?? '-';
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
                              return InkWell(
                                onTap: () => _showSaleDetail(sale),
                                child: Container(
                                  color: voided ? GoldenityColors.surface2.withValues(alpha: 0.4) : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: GoldenitySpacing.lg, vertical: 10),
                                  child: Row(
                                    children: <Widget>[
                                      SizedBox(
                                        width: 64,
                                        child: Text('#$id',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: voided ? GoldenityColors.muted : GoldenityColors.text,
                                              decoration: voided ? TextDecoration.lineThrough : null,
                                            )),
                                      ),
                                      SizedBox(
                                        width: 108,
                                        child: Text(
                                          DateFormat('dd MMM · HH:mm', 'id_ID').format(createdAt),
                                          style: const TextStyle(
                                              fontSize: 12, color: GoldenityColors.text2),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          '$cashierName · $orderType',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 12.5, color: GoldenityColors.text2),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 120,
                                        child: Text(
                                          _currencyFormatter.format(totalRaw),
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: voided ? GoldenityColors.muted : GoldenityColors.text,
                                            decoration: voided ? TextDecoration.lineThrough : null,
                                            fontFamily: GoldenityTypography.fontFamilyMono,
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 92,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: chipBg,
                                              borderRadius: BorderRadius.circular(GoldenityRadius.full),
                                            ),
                                            child: Text(
                                              _statusLabel(statusRaw),
                                              style: TextStyle(
                                                  color: chipFg, fontSize: 10.5, fontWeight: FontWeight.w800),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 56,
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text('Detail',
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: GoldenityColors.primary)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
      ),
    );
  }
}

/// Tab filter status — Figma: pill, aktif bg #1D4ED8 putih + angka badge.
class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.full),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? GoldenityColors.primary : GoldenityColors.surface,
            borderRadius: BorderRadius.circular(GoldenityRadius.full),
            border: Border.all(color: active ? GoldenityColors.primary : GoldenityColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : GoldenityColors.muted,
                  )),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? Colors.white.withValues(alpha: 0.25) : GoldenityColors.surface2,
                  borderRadius: BorderRadius.circular(GoldenityRadius.full),
                ),
                child: Text('$count',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : GoldenityColors.text2,
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColLabel extends StatelessWidget {
  const _ColLabel(this.label, {this.end = false, this.center = false});
  final String label;
  final bool end;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: end ? TextAlign.right : (center ? TextAlign.center : TextAlign.left),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.05,
        color: GoldenityColors.muted,
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
