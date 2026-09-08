// Helper _ok/_err & dialog onPrimary sudah guard `context.mounted` di dalamnya;
// lint di call-site jadi noise.
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../shared/widgets/goldenity_buttons.dart';
import '../../../shared/widgets/goldenity_modal.dart';
import '../models/dining_table.dart';
import '../providers/table_provider.dart';

/// Manajemen Meja — grid meja + QR + sesi pesanan (Figma arch-sleek `TableManager`).
class TableManagementScreen extends ConsumerWidget {
  const TableManagementScreen({super.key});

  static final _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static String statusLabel(String s) => switch (s) {
        'OCCUPIED' => 'Terisi',
        'RESERVED' => 'Reservasi',
        'CLEANING' => 'Bersih-bersih',
        'INACTIVE' => 'Nonaktif',
        _ => 'Tersedia',
      };

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
                                    _LegendDot(color: Color(0xFF64748B), label: 'Bersih-bersih'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          GoldenityAddButton(
                            label: 'Tambah Meja',
                            onTap: () => _showAddTable(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: GoldenitySpacing.md),
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
                          _CountChip('${state.countByStatus('CLEANING')} Bersih-bersih',
                              GoldenityColors.surface2, GoldenityColors.muted),
                        ],
                      ),
                      const SizedBox(height: GoldenitySpacing.lg),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisSpacing: GoldenitySpacing.md,
                          crossAxisSpacing: GoldenitySpacing.md,
                          childAspectRatio: 1.05,
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

  // ─────────────────────────── Add table ───────────────────────────
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
              label: 'Kode / Nama Meja',
              controller: codeCtrl,
              hint: 'mis. Meja 8 atau VIP 3',
              autofocus: true),
          const SizedBox(height: 14),
          GoldenityModalField(
              label: 'Kapasitas (orang)',
              controller: capCtrl,
              hint: 'mis. 4',
              keyboardType: TextInputType.number),
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
          _err(context, e);
          return null;
        }
      },
    );
  }

  // ─────────────────────────── Detail drawer ───────────────────────────
  Future<void> _showTableDetail(BuildContext context, WidgetRef ref, DiningTable table) async {
    final n = ref.read(tableListProvider.notifier);
    final status = table.status;

    List<Widget> actions;
    Widget body;

    if (status == 'OCCUPIED') {
      actions = [
        GoldenityOutlineButton(
          label: 'Tutup Sesi',
          icon: Icons.event_available_rounded,
          color: GoldenityColors.error,
          borderColor: const Color(0xFFFECACA),
          onTap: () => _run(context, () => n.closeSession(table.id), 'Sesi meja ditutup'),
        ),
      ];
      body = _OccupiedBody(tableId: table.id, currency: _currency);
    } else if (status == 'RESERVED') {
      final r = table.reservation;
      actions = [
        GoldenityFillButton(
          label: 'Check In (Buka Sesi)',
          icon: Icons.login_rounded,
          color: GoldenityColors.success,
          onTap: () => _run(context, () => n.checkinReservation(table.id), 'Reservasi check-in, sesi dibuka'),
        ),
        GoldenityOutlineButton(
          label: 'Batalkan Reservasi',
          color: GoldenityColors.error,
          borderColor: const Color(0xFFFECACA),
          onTap: () => _run(context, () => n.cancelReservation(table.id), 'Reservasi dibatalkan'),
        ),
      ];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('DETAIL RESERVASI',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.06,
                  color: GoldenityColors.primary)),
          const SizedBox(height: 8),
          _kv('Nama', r?.name ?? '—'),
          _kv('No. HP', r?.phone ?? '—'),
          _kv('Tanggal',
              r?.reservedAt != null ? DateFormat('yyyy-MM-dd · HH:mm').format(r!.reservedAt!) : '—'),
          _kv('Tamu', '${r?.guests ?? '-'} orang'),
          if (r?.note != null && r!.note!.trim().isNotEmpty) _kv('Catatan', r.note!),
        ],
      );
    } else if (status == 'CLEANING') {
      actions = [
        GoldenityFillButton(
          label: 'Tandai Meja Siap',
          icon: Icons.check_circle_rounded,
          color: GoldenityColors.success,
          onTap: () =>
              _run(context, () => n.updateTable(table.id, status: 'AVAILABLE'), 'Meja siap dipakai'),
        ),
      ];
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('Meja sedang dibersihkan. Tandai siap bila sudah selesai.',
            style: TextStyle(fontSize: 13, color: GoldenityColors.muted)),
      );
    } else {
      // AVAILABLE (atau INACTIVE)
      actions = [
        GoldenityFillButton(
          label: 'Buka Sesi Baru',
          icon: Icons.play_arrow_rounded,
          color: GoldenityColors.success,
          onTap: () {
            Navigator.of(context).maybePop();
            _showOpenSessionDialog(context, ref, table);
          },
        ),
        GoldenityOutlineButton(
          label: 'Buat Reservasi',
          color: GoldenityColors.primary,
          borderColor: GoldenityColors.primary,
          onTap: () {
            Navigator.of(context).maybePop();
            _showReserveDialog(context, ref, table);
          },
        ),
        GoldenityOutlineButton(
          label: 'Generate QR Meja',
          onTap: () {
            Navigator.of(context).maybePop();
            _showQrDialog(context, ref, table);
          },
        ),
      ];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _kv('Status', statusLabel(status)),
          _kv('Kapasitas', '${table.capacity ?? '-'} orang'),
          const SizedBox(height: 8),
          const Text('Meja kosong — buka sesi walk-in, buat reservasi, atau bagikan QR '
              'supaya pelanggan pesan sendiri dari HP.',
              style: TextStyle(fontSize: 12.5, color: GoldenityColors.muted, height: 1.4)),
        ],
      );
    }

    await showGoldenityDetailDrawer<void>(
      context: context,
      id: table.code,
      subtitle: statusLabel(status) +
          (table.capacity != null ? ' · ${table.capacity} orang' : ''),
      width: 360,
      actions: actions,
      child: body,
    );
  }

  // ─────────────────────────── Buka Sesi dialog ───────────────────────────
  Future<void> _showOpenSessionDialog(BuildContext context, WidgetRef ref, DiningTable table) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    int guests = 2;
    await showGoldenityDialog<bool>(
      context: context,
      title: 'Buka Sesi Meja — ${table.code}',
      primaryLabel: 'Buka Sesi',
      primaryColor: GoldenityColors.success,
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GoldenityModalField(
                label: 'Nama Tamu (opsional)',
                controller: nameCtrl,
                hint: 'Masukkan nama tamu...',
                autofocus: true),
            const SizedBox(height: 12),
            GoldenityModalField(
                label: 'No. HP Tamu (opsional)',
                controller: phoneCtrl,
                hint: '08xx-xxxx-xxxx',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _GuestStepper(
              value: guests,
              max: table.capacity ?? 20,
              onChanged: (v) => setLocal(() => guests = v),
              capacityHint: table.capacity,
            ),
          ],
        ),
      ),
      onPrimary: () async {
        try {
          await ref.read(tableListProvider.notifier).openSession(
                table.id,
                guestName: nameCtrl.text.trim(),
                guestPhone: phoneCtrl.text.trim(),
                guests: guests,
              );
          _ok(context, 'Sesi meja dibuka');
          return true;
        } catch (e) {
          _err(context, e);
          return null;
        }
      },
    );
  }

  // ─────────────────────────── Reservasi dialog ───────────────────────────
  Future<void> _showReserveDialog(BuildContext context, WidgetRef ref, DiningTable table) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    DateTime date = DateTime.now();
    TimeOfDay time = const TimeOfDay(hour: 12, minute: 0);
    int guests = 2;

    await showGoldenityDialog<bool>(
      context: context,
      title: 'Buat Reservasi — ${table.code}',
      primaryLabel: 'Buat Reservasi',
      child: StatefulBuilder(
        builder: (ctx, setLocal) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GoldenityModalField(
                label: 'Nama Pemesan *',
                controller: nameCtrl,
                hint: 'Masukkan nama pemesan...',
                autofocus: true),
            const SizedBox(height: 12),
            GoldenityModalField(
                label: 'No. HP *',
                controller: phoneCtrl,
                hint: '08xx-xxxx-xxxx',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickerField(
                    label: 'Tanggal',
                    value: DateFormat('dd/MM/yyyy').format(date),
                    icon: Icons.calendar_today_rounded,
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime.now().subtract(const Duration(days: 1)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setLocal(() => date = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerField(
                    label: 'Jam',
                    value: time.format(ctx),
                    icon: Icons.access_time_rounded,
                    onTap: () async {
                      final t = await showTimePicker(context: ctx, initialTime: time);
                      if (t != null) setLocal(() => time = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _GuestStepper(
              value: guests,
              max: table.capacity ?? 20,
              onChanged: (v) => setLocal(() => guests = v),
              capacityHint: table.capacity,
            ),
            const SizedBox(height: 12),
            GoldenityModalField(
                label: 'Catatan / Permintaan Khusus (opsional)',
                controller: noteCtrl,
                hint: 'Contoh: meja dekat jendela, alergi kacang...',
                maxLines: 2),
          ],
        ),
      ),
      onPrimary: () async {
        if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().length < 4) {
          _err(context, 'Nama & No. HP wajib diisi');
          return null;
        }
        final at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        try {
          await ref.read(tableListProvider.notifier).reserve(
                table.id,
                name: nameCtrl.text.trim(),
                phone: phoneCtrl.text.trim(),
                reservedAt: at,
                guests: guests,
                note: noteCtrl.text.trim(),
              );
          _ok(context, 'Reservasi dibuat');
          return true;
        } catch (e) {
          _err(context, e);
          return null;
        }
      },
    );
  }

  // ─────────────────────────── QR dialog ───────────────────────────
  Future<void> _showQrDialog(BuildContext context, WidgetRef ref, DiningTable table) async {
    final svc = ref.read(tableApiServiceProvider);
    final token = ref.read(authTokenProvider);
    String qrUrl = '';
    try {
      qrUrl = await svc.qrUrl(token: token, tableId: table.id);
    } catch (_) {}
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('QR Meja — ${table.code}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Cetak & tempel di meja. Pelanggan scan untuk pesan sendiri.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: GoldenityColors.muted)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GoldenityColors.border),
                ),
                child: QrImageView(
                  data: qrUrl.isEmpty ? table.qrToken : qrUrl,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(qrUrl.isEmpty ? table.qrToken : qrUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, color: GoldenityColors.muted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GoldenityOutlineButton(
                      label: 'Ganti Token (rotate)',
                      color: GoldenityColors.error,
                      borderColor: const Color(0xFFFECACA),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        // rotate hanya endpoint admin; reuse updateTable? -> pakai closeSession bila perlu.
                        // Sederhana: panggil ulang list; token rotate tersedia bila status kembali AVAILABLE.
                        _ok(context, 'Gunakan "Tutup Sesi" untuk memutar token QR.');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GoldenityFillButton(
                      label: 'Tutup',
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ─────────────────────────── helpers ───────────────────────────
  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 12, color: GoldenityColors.muted)),
            Flexible(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: GoldenityColors.text)),
            ),
          ],
        ),
      );

  void _run(BuildContext context, Future<void> Function() action, String okMsg) async {
    Navigator.of(context).maybePop();
    try {
      await action();
      _ok(context, okMsg);
    } catch (e) {
      _err(context, e);
    }
  }

  void _ok(BuildContext c, String m) {
    if (!c.mounted) return;
    ScaffoldMessenger.of(c).showSnackBar(
        SnackBar(backgroundColor: GoldenityColors.success, content: Text(m)));
  }

  void _err(BuildContext c, Object e) {
    if (!c.mounted) return;
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
        backgroundColor: GoldenityColors.error,
        content: Text(e.toString().replaceAll('Exception: ', ''))));
  }
}

class _OccupiedBody extends ConsumerWidget {
  const _OccupiedBody({required this.tableId, required this.currency});
  final String tableId;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tableSessionDetailProvider(tableId));
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
              _OrderBlock(order: o, currency: currency),
              const SizedBox(height: 10),
            ],
            const Divider(height: 1, color: GoldenityColors.border),
            const SizedBox(height: 10),
            _row('Total Pesanan', '${d.orderCount} order'),
            _row('Belum Dibayar', '${d.unpaidCount} order'),
            _row('Grand Total', currency.format(d.grandTotal), bold: true),
            _row('Sisa Tagihan', currency.format(d.unpaidTotal),
                color: d.unpaidTotal > 0 ? GoldenityColors.error : GoldenityColors.success),
          ],
        );
      },
    );
  }

  static Widget _row(String k, String v, {bool bold = false, Color? color}) => Padding(
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
        'CLEANING' => (const Color(0xFFF0FDF4), const Color(0xFFBBF7D0), GoldenityColors.success),
        'INACTIVE' => (GoldenityColors.surface2, GoldenityColors.border, GoldenityColors.muted),
        _ => (GoldenityColors.surface, GoldenityColors.border, GoldenityColors.success),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, border, accent) = _palette;
    final s = table.activeSession;
    final r = table.reservation;
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
                child: Text(TableManagementScreen.statusLabel(table.status),
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
              ] else if (r != null) ...[
                Text(r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: GoldenityColors.text2)),
                if (r.reservedAt != null)
                  Text(DateFormat('dd MMM HH:mm').format(r.reservedAt!),
                      style: const TextStyle(fontSize: 10, color: GoldenityColors.muted)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestStepper extends StatelessWidget {
  const _GuestStepper({
    required this.value,
    required this.onChanged,
    this.max = 20,
    this.capacityHint,
  });
  final int value;
  final ValueChanged<int> onChanged;
  final int max;
  final int? capacityHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Jumlah Tamu',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        Row(
          children: [
            _btn(Icons.remove_rounded, value > 1 ? () => onChanged(value - 1) : null),
            Container(
              width: 44,
              alignment: Alignment.center,
              child: Text('$value',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: GoldenityTypography.fontFamilyMono)),
            ),
            _btn(Icons.add_rounded, value < max ? () => onChanged(value + 1) : null),
          ],
        ),
        if (capacityHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('🪑 Kapasitas meja: $capacityHint orang',
                style: const TextStyle(fontSize: 11, color: GoldenityColors.muted)),
          ),
      ],
    );
  }

  Widget _btn(IconData i, VoidCallback? onTap) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GoldenityRadius.sm),
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GoldenityRadius.sm),
              border: Border.all(color: GoldenityColors.border),
            ),
            child: Icon(i, size: 16, color: onTap == null ? GoldenityColors.disabled : GoldenityColors.text2),
          ),
        ),
      );
}

class _PickerField extends StatelessWidget {
  const _PickerField(
      {required this.label, required this.value, required this.icon, required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: GoldenityColors.surface2,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              border: Border.all(color: GoldenityColors.border),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: GoldenityColors.muted),
                const SizedBox(width: 8),
                Text(value, style: const TextStyle(fontSize: 13, color: GoldenityColors.text)),
              ],
            ),
          ),
        ),
      ],
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
