import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../shared/widgets/goldenity_modal.dart';
import '../models/web_order.dart';
import '../providers/web_order_provider.dart';

/// Web Orders (kasir) — Figma arch-sleek `WebOrdersManager`.
class WebOrdersScreen extends ConsumerStatefulWidget {
  const WebOrdersScreen({super.key});

  @override
  ConsumerState<WebOrdersScreen> createState() => _WebOrdersScreenState();
}

class _WebOrdersScreenState extends ConsumerState<WebOrdersScreen> {
  int _tab = 0; // 0 = Baru, 1 = Semua
  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(webOrderListProvider);
    final notifier = ref.read(webOrderListProvider.notifier);
    final visible = _tab == 0 ? state.baru : state.orders;

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      body: state.loading && state.orders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.orders.isEmpty
              ? _ErrorState(message: state.error!, onRetry: notifier.load)
              : RefreshIndicator(
                  onRefresh: notifier.load,
                  color: GoldenityColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(GoldenitySpacing.lg),
                    children: [
                      Row(
                        children: [
                          const Text('Web Orders',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: GoldenityColors.text)),
                          const SizedBox(width: 16),
                          _Tab('Baru', state.baruCount, _tab == 0, () => setState(() => _tab = 0)),
                          const SizedBox(width: 6),
                          _Tab('Semua', state.orders.length, _tab == 1, () => setState(() => _tab = 1)),
                        ],
                      ),
                      const SizedBox(height: GoldenitySpacing.lg),
                      if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text('Tidak ada pesanan.',
                                style: TextStyle(color: GoldenityColors.muted)),
                          ),
                        )
                      else
                        for (final o in visible) ...[
                          _OrderCard(
                            order: o,
                            currency: _currency,
                            onAccept: () => _do(() => notifier.accept(o.id), 'Pesanan diterima'),
                            onReject: () => _reject(o),
                            onAdvance: (s) => _do(() => notifier.advance(o.id, s), 'Status: $s'),
                            onVerifyPayment: () =>
                                _do(() => notifier.verifyPayment(o.id), 'Pembayaran diverifikasi'),
                          ),
                          const SizedBox(height: GoldenitySpacing.md),
                        ],
                    ],
                  ),
                ),
    );
  }

  Future<void> _do(Future<void> Function() action, String okMsg) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: GoldenityColors.success, content: Text(okMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: GoldenityColors.error,
            content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  Future<void> _reject(WebOrder o) async {
    final ctrl = TextEditingController();
    await showGoldenityDialog<bool>(
      context: context,
      title: 'Tolak Pesanan',
      subtitle: 'Antrean #${o.queueNumber}',
      primaryLabel: 'Tolak',
      primaryColor: GoldenityColors.error,
      child: GoldenityModalField(
          label: 'Alasan (opsional)', controller: ctrl, hint: 'mis. stok habis', autofocus: true),
      onPrimary: () async {
        await _do(() => ref.read(webOrderListProvider.notifier).reject(o.id, ctrl.text.trim()),
            'Pesanan ditolak');
        return true;
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.currency,
    required this.onAccept,
    required this.onReject,
    required this.onAdvance,
    required this.onVerifyPayment,
  });
  final WebOrder order;
  final NumberFormat currency;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final void Function(String status) onAdvance;
  final VoidCallback onVerifyPayment;

  static const _flow = ['ACCEPTED', 'PREPARING', 'READY', 'SERVED', 'COMPLETED'];

  /// URL bukti transfer yang valid untuk `Image.network` (absolut http/https).
  String? get _proofUrl {
    final raw = order.paymentProofUrl?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('/')) return 'http://localhost:3001$raw';
    return null;
  }

  String? get _nextStatus {
    final i = _flow.indexOf(order.status);
    if (i < 0 || i + 1 >= _flow.length) return null;
    return _flow[i + 1];
  }

  @override
  Widget build(BuildContext context) {
    final (sBg, sFg) = _statusColor(order.status);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        border: Border.all(color: order.isNew ? const Color(0xFFFDE68A) : GoldenityColors.border),
        boxShadow: GoldenityElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (order.isNew)
            Container(
              width: double.infinity,
              color: GoldenityColors.warningLight,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: const Row(children: [
                Icon(Icons.bolt_rounded, size: 14, color: GoldenityColors.warning),
                SizedBox(width: 5),
                Text('Pesanan Baru! Segera konfirmasi',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800, color: GoldenityColors.warning)),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('#${order.queueNumber}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: GoldenityColors.primary)),
                              if (order.tableCode != null) ...[
                                const SizedBox(width: 6),
                                Text('· ${order.tableCode}',
                                    style: const TextStyle(
                                        fontSize: 12, color: GoldenityColors.muted)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(order.customerName ?? 'Pelanggan',
                              style: const TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w700, color: GoldenityColors.text)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (order.createdAt != null)
                          Text(DateFormat('HH:mm').format(order.createdAt!),
                              style: const TextStyle(fontSize: 11, color: GoldenityColors.muted)),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                              color: sBg, borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
                          child: Text(order.status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: sFg)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final it in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Text(
                      '• ${it.productName} ×${it.qty}'
                      '${it.note != null && it.note!.trim().isNotEmpty ? '  (${it.note})' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: GoldenityColors.text2),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(currency.format(order.total),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFamily: GoldenityTypography.fontFamilyMono)),
                    const SizedBox(width: 8),
                    _chip(order.paymentMethod == 'QRIS_STATIC' ? 'QRIS' : 'Bayar di Kasir',
                        GoldenityColors.primaryLight, GoldenityColors.primary),
                    const SizedBox(width: 6),
                    _chip(_payLabel(order.paymentStatus), _payBg(order.paymentStatus),
                        _payFg(order.paymentStatus)),
                  ],
                ),
                if (order.customerNote != null && order.customerNote!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: GoldenityColors.warningLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(GoldenityRadius.md),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text('📝 ${order.customerNote}',
                        style: const TextStyle(fontSize: 12, color: GoldenityColors.text2)),
                  ),
                ],
                if (order.rejectionReason != null && order.rejectionReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text('Ditolak: ${order.rejectionReason}',
                      style: const TextStyle(fontSize: 12, color: GoldenityColors.error)),
                ],
                if (_proofUrl != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: InteractiveViewer(child: Image.network(_proofUrl!)),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(GoldenityRadius.md),
                      child: Image.network(
                        _proofUrl!,
                        height: 110,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (c, w, p) => p == null
                            ? w
                            : Container(
                                height: 44,
                                alignment: Alignment.center,
                                color: GoldenityColors.surface2,
                                child: const Text('Memuat bukti…',
                                    style: TextStyle(fontSize: 11, color: GoldenityColors.muted)),
                              ),
                        errorBuilder: (_, __, ___) => Container(
                          height: 44,
                          alignment: Alignment.center,
                          color: GoldenityColors.surface2,
                          child: const Text('Bukti transfer tidak dapat dimuat',
                              style: TextStyle(fontSize: 11, color: GoldenityColors.muted)),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _actions(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context) {
    if (order.isNew) {
      return Row(
        children: [
          Expanded(
            flex: 60,
            child: _btn('Terima', GoldenityColors.success, filled: true, onTap: onAccept),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 40,
            child: _btn('Tolak', GoldenityColors.error, filled: false, onTap: onReject),
          ),
        ],
      );
    }
    if (order.isDone) return const SizedBox.shrink();
    return Row(
      children: [
        if (order.paymentStatus == 'PENDING_VERIFICATION')
          Expanded(
            child: _btn('Verifikasi Bayar', GoldenityColors.primary,
                filled: true, onTap: onVerifyPayment),
          ),
        if (order.paymentStatus == 'PENDING_VERIFICATION' && _nextStatus != null)
          const SizedBox(width: 8),
        if (_nextStatus != null)
          Expanded(
            child: _btn(_advanceLabel(_nextStatus!), GoldenityColors.primary,
                filled: true, onTap: () => onAdvance(_nextStatus!)),
          ),
      ],
    );
  }

  static String _advanceLabel(String s) => switch (s) {
        'PREPARING' => 'Mulai Masak',
        'READY' => 'Siap Antar',
        'SERVED' => 'Sudah Diantar',
        'COMPLETED' => 'Selesaikan',
        _ => s,
      };

  Widget _btn(String label, Color color, {required bool filled, required VoidCallback onTap}) =>
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GoldenityRadius.lg),
          onTap: onTap,
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? color : GoldenityColors.surface,
              borderRadius: BorderRadius.circular(GoldenityRadius.lg),
              border: filled ? null : Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: filled ? Colors.white : color)),
          ),
        ),
      );

  Widget _chip(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
        child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg)),
      );

  static (Color, Color) _statusColor(String s) => switch (s) {
        'SUBMITTED' => (GoldenityColors.warningLight, GoldenityColors.warning),
        'CANCELLED' => (GoldenityColors.errorLight, GoldenityColors.error),
        'COMPLETED' => (GoldenityColors.successLight, GoldenityColors.success),
        _ => (GoldenityColors.primaryLight, GoldenityColors.primary),
      };
  static String _payLabel(String s) => switch (s) {
        'PAID' => 'Lunas',
        'PENDING_VERIFICATION' => 'Cek Bukti',
        _ => 'Belum Bayar',
      };
  static Color _payBg(String s) => switch (s) {
        'PAID' => GoldenityColors.successLight,
        'PENDING_VERIFICATION' => GoldenityColors.warningLight,
        _ => GoldenityColors.surface2,
      };
  static Color _payFg(String s) => switch (s) {
        'PAID' => GoldenityColors.success,
        'PENDING_VERIFICATION' => GoldenityColors.warning,
        _ => GoldenityColors.muted,
      };
}

class _Tab extends StatelessWidget {
  const _Tab(this.label, this.count, this.active, this.onTap);
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
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
            child: Text('$label ($count)',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : GoldenityColors.muted)),
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: GoldenityColors.error),
            const SizedBox(height: GoldenitySpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: GoldenitySpacing.md),
            OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi')),
          ]),
        ),
      );
}
