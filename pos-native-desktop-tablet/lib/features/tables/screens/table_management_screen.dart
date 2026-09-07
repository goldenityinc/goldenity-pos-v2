import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../shared/widgets/goldenity_modal.dart';
import '../models/dining_table.dart';
import '../providers/table_provider.dart';

/// Manajemen Meja — grid meja + QR + sesi pesanan (Figma arch-sleek `TableManager`).
class TableManagementScreen extends ConsumerWidget {
  const TableManagementScreen({super.key});

  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tableListProvider);
    final notifier = ref.read(tableListProvider.notifier);

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      body: state.loading && state.tables.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.tables.isEmpty
              ? _ErrorState(message: state.error!, onRetry: notifier.load)
              : RefreshIndicator(
                  onRefresh: notifier.load,
                  color: GoldenityColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(GoldenitySpacing.lg),
                    children: [
                      // ── Header ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Manajemen Meja',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: GoldenityColors.text)),
                                SizedBox(height: 6),
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 6,
                                  children: [
                                    _LegendDot(color: GoldenityColors.success, label: 'Tersedia'),
                                    _LegendDot(color: GoldenityColors.warning, label: 'Terisi'),
                                    _LegendDot(color: GoldenityColors.primary, label: 'Reservasi'),
                                    _LegendDot(color: GoldenityColors.disabled, label: 'Nonaktif'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _AddButton(onTap: () => _showAddTable(context, ref)),
                        ],
                      ),
                      const SizedBox(height: GoldenitySpacing.md),
                      // ── Count chips ──
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CountChip('${state.countByStatus('AVAILABLE')} Tersedia',
                              GoldenityColors.successLight, GoldenityColors.success),
                          _CountChip('${state.countByStatus('OCCUPIED')} Terisi',
                              GoldenityColors.warningLight, GoldenityColors.warning),
                          _CountChip('${state.countByStatus('RESERVED')} Reservasi',
                              GoldenityColors.primaryLight, GoldenityColors.primary),
                          _CountChip('${state.countByStatus('INACTIVE')} Nonaktif',
                              GoldenityColors.surface2, GoldenityColors.muted),
                        ],
                      ),
                      const SizedBox(height: GoldenitySpacing.lg),
                      // ── Grid ──
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: GoldenitySpacing.md,
                          crossAxisSpacing: GoldenitySpacing.md,
                          childAspectRatio: 1.08,
                        ),
                        itemCount: state.tables.length,
                        itemBuilder: (ctx, i) => _TableCard(
                          table: state.tables[i],
                          currency: _currency,
                          onTap: () => _showTableDetail(context, ref, state.tables[i]),
                        ),
                      ),
                      if (state.tables.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text('Belum ada meja. Tekan "Tambah Meja".',
                                style: TextStyle(color: GoldenityColors.muted)),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showAddTable(BuildContext context, WidgetRef ref) async {
    final codeCtrl = TextEditingController();
    final capCtrl = TextEditingController();
    await showGoldenityDialog<bool>(
      context: context,
      title: 'Tambah Meja',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GoldenityModalField(
              label: 'Kode / Nama Meja', controller: codeCtrl, hint: 'mis. Meja 8 atau VIP 3', autofocus: true),
          const SizedBox(height: 14),
          GoldenityModalField(
              label: 'Kapasitas (orang)', controller: capCtrl, hint: 'mis. 4', keyboardType: TextInputType.number),
        ],
      ),
      onPrimary: () async {
        final code = codeCtrl.text.trim();
        if (code.isEmpty) return null;
        try {
          await ref
              .read(tableListProvider.notifier)
              .createTable(code, int.tryParse(capCtrl.text.trim()));
          return true;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: GoldenityColors.error,
                content: Text(e.toString().replaceAll('Exception: ', ''))));
          }
          return null;
        }
      },
    );
  }

  Future<void> _showTableDetail(BuildContext context, WidgetRef ref, DiningTable table) async {
    await showGoldenityDetailDrawer<void>(
      context: context,
      id: table.code,
      subtitle: '${_statusLabel(table.status)}'
          '${table.capacity != null ? ' · ${table.capacity} orang' : ''}',
      width: 360,
      actions: [
        if (table.activeSession != null)
          GoldenityDrawerAction(
            label: 'Tutup Sesi',
            icon: Icons.event_available_rounded,
            color: GoldenityColors.error,
            borderColor: const Color(0xFFFECACA),
            onTap: () async {
              Navigator.of(context).maybePop();
              try {
                await ref.read(tableListProvider.notifier).closeSession(table.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sesi meja ditutup.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      backgroundColor: GoldenityColors.error,
                      content: Text(e.toString().replaceAll('Exception: ', ''))));
                }
              }
            },
          ),
        GoldenityDrawerAction(
          label: 'Ubah Status',
          icon: Icons.tune_rounded,
          onTap: () {
            Navigator.of(context).maybePop();
            _showStatusPicker(context, ref, table);
          },
        ),
      ],
      child: Consumer(
        builder: (context, ref2, _) {
          final detail = ref2.watch(tableSessionDetailProvider(table.id));
          return detail.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Gagal memuat: $e',
                style: const TextStyle(color: GoldenityColors.error, fontSize: 12)),
            data: (d) {
              if (d.session == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Belum ada sesi aktif di meja ini.',
                      style: TextStyle(color: GoldenityColors.muted, fontSize: 13)),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Pelanggan: ${d.session!.customerName ?? '—'}'
                    '${d.session!.customerPhone != null ? ' · ${d.session!.customerPhone}' : ''}',
                    style: const TextStyle(fontSize: 12, color: GoldenityColors.text2),
                  ),
                  if (d.session!.openedAt != null)
                    Text('Dibuka ${DateFormat('d MMM • HH:mm', 'id_ID').format(d.session!.openedAt!)}',
                        style: const TextStyle(fontSize: 11, color: GoldenityColors.muted)),
                  const SizedBox(height: 14),
                  for (final o in d.orders) ...[
                    _OrderBlock(order: o, currency: _currency),
                    const SizedBox(height: 10),
                  ],
                  const Divider(height: 1, color: GoldenityColors.border),
                  const SizedBox(height: 10),
                  _kv('Total Pesanan', '${d.orderCount} order'),
                  _kv('Belum Dibayar', '${d.unpaidCount} order'),
                  _kv('Grand Total', _currency.format(d.grandTotal), bold: true),
                  _kv('Sisa Tagihan', _currency.format(d.unpaidTotal),
                      color: d.unpaidTotal > 0 ? GoldenityColors.error : GoldenityColors.success),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showStatusPicker(BuildContext context, WidgetRef ref, DiningTable table) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final s in const [
              ('AVAILABLE', 'Tersedia'),
              ('OCCUPIED', 'Terisi'),
              ('RESERVED', 'Reservasi'),
              ('INACTIVE', 'Nonaktif'),
            ])
              ListTile(
                title: Text(s.$2),
                trailing: table.status == s.$1 ? const Icon(Icons.check_rounded) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(tableListProvider.notifier).updateTable(table.id, status: s.$1);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: GoldenityColors.error,
                          content: Text(e.toString().replaceAll('Exception: ', ''))));
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    fontSize: bold ? 13.5 : 12.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                    color: GoldenityColors.text2)),
            Text(v,
                style: TextStyle(
                  fontSize: bold ? 13.5 : 12.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: color ?? GoldenityColors.text,
                  fontFamily: GoldenityTypography.fontFamilyMono,
                )),
          ],
        ),
      );

  static String _statusLabel(String s) => switch (s) {
        'OCCUPIED' => 'Terisi',
        'RESERVED' => 'Reservasi',
        'INACTIVE' => 'Nonaktif',
        _ => 'Tersedia',
      };
}

class _OrderBlock extends StatelessWidget {
  const _OrderBlock({required this.order, required this.currency});
  final WebOrderInSession order;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final paid = order.paymentStatus == 'PAID';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: GoldenityColors.surface2,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('#${order.queueNumber}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              _tag(order.status, GoldenityColors.primaryLight, GoldenityColors.primary),
              const Spacer(),
              _tag(paid ? 'LUNAS' : 'BELUM',
                  paid ? GoldenityColors.successLight : GoldenityColors.warningLight,
                  paid ? GoldenityColors.success : GoldenityColors.warning),
            ],
          ),
          const SizedBox(height: 6),
          for (final it in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text('${it.qty}× ${it.productName}',
                  style: const TextStyle(fontSize: 11.5, color: GoldenityColors.text2)),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(currency.format(order.total),
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    fontFamily: GoldenityTypography.fontFamilyMono)),
          ),
        ],
      ),
    );
  }

  Widget _tag(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GoldenityRadius.xs)),
        child: Text(t, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
      );
}

class _TableCard extends StatelessWidget {
  const _TableCard({required this.table, required this.currency, required this.onTap});
  final DiningTable table;
  final NumberFormat currency;
  final VoidCallback onTap;

  (Color, Color, Color) get _palette => switch (table.status) {
        'OCCUPIED' => (const Color(0xFFFFFBEB), const Color(0xFFFDE68A), GoldenityColors.warning),
        'RESERVED' => (const Color(0xFFEFF6FF), const Color(0xFFBFDBFE), GoldenityColors.primary),
        'INACTIVE' => (GoldenityColors.surface2, GoldenityColors.border, GoldenityColors.muted),
        _ => (GoldenityColors.surface, GoldenityColors.border, GoldenityColors.success),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, border, accent) = _palette;
    final s = table.activeSession;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(GoldenitySpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(GoldenityRadius.xl),
            border: Border.all(color: border),
            boxShadow: GoldenityElevation.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (table.isVip) ...[
                    const Icon(Icons.workspace_premium_rounded, size: 14, color: GoldenityColors.warning),
                    const SizedBox(width: 3),
                  ],
                  Text(table.code,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 12, color: GoldenityColors.muted),
                  const SizedBox(width: 3),
                  Text('${table.capacity ?? '-'} orang',
                      style: const TextStyle(fontSize: 11, color: GoldenityColors.muted)),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(GoldenityRadius.full),
                ),
                child: Text(TableManagementScreen._statusLabel(table.status),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent)),
              ),
              const Spacer(),
              if (s != null && s.orders.isNotEmpty) ...[
                Text('#${s.orders.first.queueNumber}'
                    '${s.orderCount > 1 ? ' +${s.orderCount - 1}' : ''}',
                    style: const TextStyle(fontSize: 10.5, color: GoldenityColors.text2)),
                if (s.openedAt != null)
                  Text('Sejak ${DateFormat('HH:mm').format(s.openedAt!)}',
                      style: const TextStyle(fontSize: 10, color: GoldenityColors.muted)),
                Text(currency.format(s.grandTotal),
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: GoldenityColors.primary,
                        fontFamily: GoldenityTypography.fontFamilyMono)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11.5, color: GoldenityColors.text2)),
        ],
      );
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.bg, this.fg);
  final String label;
  final Color bg;
  final Color fg;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GoldenityRadius.full)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      );
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: GoldenityColors.primary,
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(GoldenityRadius.lg),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text('Tambah Meja',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
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
