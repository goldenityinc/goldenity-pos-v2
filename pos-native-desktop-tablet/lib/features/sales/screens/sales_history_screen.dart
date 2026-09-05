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

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => _loadSales(initial: true));
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
    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        title: const Text('Riwayat Penjualan'),
        backgroundColor: Colors.transparent,
        foregroundColor: biz.base,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _isLoading ? null : () => _loadSales(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSales(),
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(GoldenitySpacing.lg),
                        itemCount: _sales.length,
                        itemBuilder: (ctx, i) {
                          final sale = _sales[i];
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
                                onTap: () => _openVoidDialog(sale),
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
