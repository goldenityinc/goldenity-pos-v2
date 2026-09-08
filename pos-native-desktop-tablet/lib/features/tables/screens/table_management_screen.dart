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
      // Semua aksi (bayar per-order / bayar semua / tutup sesi) dirender di
      // dalam body karena bergantung pada data sesi yang dimuat async.
      actions = const [];
      body = _OccupiedBody(tableId: table.id, tableCode: table.code, currency: _currency);
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

class _OccupiedBody extends ConsumerStatefulWidget {
  const _OccupiedBody({
    required this.tableId,
    required this.tableCode,
    required this.currency,
  });
  final String tableId;
  final String tableCode;
  final NumberFormat currency;

  @override
  ConsumerState<_OccupiedBody> createState() => _OccupiedBodyState();
}

class _OccupiedBodyState extends ConsumerState<_OccupiedBody> {
  final Set<String> _selected = {};
  bool _closing = false;

  NumberFormat get _c => widget.currency;

  void _toggle(String id) => setState(() {
        if (!_selected.remove(id)) _selected.add(id);
      });

  Future<void> _openPayment(List<WebOrderInSession> orders) async {
    if (orders.isEmpty) return;
    final res = await showGeneralDialog<SettleResult>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Pembayaran',
      barrierColor: const Color(0x73000000),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, a1, __, ___) {
        final curved = CurvedAnimation(parent: a1, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: _TablePaymentDialog(
              tableId: widget.tableId,
              tableCode: widget.tableCode,
              orders: orders,
              currency: _c,
            ),
          ),
        );
      },
    );
    if (!mounted || res == null) return;
    setState(() => _selected.clear());
    final msg = StringBuffer(res.message);
    if (res.cashChange != null && res.cashChange! > 0) {
      msg.write(' · Kembalian ${_c.format(res.cashChange)}');
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: GoldenityColors.success, content: Text(msg.toString())),
    );
  }

  Future<void> _closeSession() async {
    setState(() => _closing = true);
    try {
      await ref.read(tableListProvider.notifier).closeSession(widget.tableId);
      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: GoldenityColors.success, content: Text('Sesi meja ditutup')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: GoldenityColors.error,
          content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  static String _fmtDur(Duration d) {
    if (d.inHours > 0) return '${d.inHours}j ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(tableSessionDetailProvider(widget.tableId));
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
        final session = d.session!;
        final orders = d.orders;
        final settleable = orders.where((o) => o.settleable).toList();
        _selected.removeWhere((id) => !settleable.any((o) => o.id == id));
        final selectedOrders = settleable.where((o) => _selected.contains(o.id)).toList();
        final selectedTotal = selectedOrders.fold<num>(0, (s, o) => s + o.total);
        final allSelected = settleable.isNotEmpty && _selected.length == settleable.length;
        final expiresIn = session.expiresAt?.difference(DateTime.now());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tamu: ${session.customerName?.trim().isNotEmpty == true ? session.customerName : 'Tamu'}'
              '${session.customerPhone != null ? ' · ${session.customerPhone}' : ''}',
              style: const TextStyle(fontSize: 12, color: GoldenityColors.text2),
            ),
            if (session.openedAt != null)
              Text('Dibuka ${DateFormat('d MMM • HH:mm', 'id_ID').format(session.openedAt!.toLocal())}',
                  style: const TextStyle(fontSize: 11, color: GoldenityColors.muted)),
            if (expiresIn != null && !expiresIn.isNegative)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Sesi berakhir dalam ${_fmtDur(expiresIn)}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600, color: GoldenityColors.warning)),
              ),
            const SizedBox(height: 12),
            Text(
              '${d.orderCount} pesanan · ${d.unpaidCount} belum lunas · ${_c.format(d.unpaidTotal)}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: GoldenityColors.text),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('DAFTAR PESANAN',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.06,
                        color: GoldenityColors.muted)),
                const Spacer(),
                if (settleable.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() {
                      if (allSelected) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(settleable.map((o) => o.id));
                      }
                    }),
                    child: Text(
                      allSelected ? 'Batal pilih' : 'Pilih Semua (${settleable.length})',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: GoldenityColors.primary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final o in orders) ...[
              _OrderRow(
                order: o,
                currency: _c,
                selected: _selected.contains(o.id),
                onToggle: o.settleable ? () => _toggle(o.id) : null,
              ),
              const SizedBox(height: 8),
            ],
            if (selectedOrders.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: GoldenityColors.primaryLight,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                  border: Border.all(color: GoldenityColors.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text('${selectedOrders.length} pesanan dipilih',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: GoldenityColors.primary)),
                        const Spacer(),
                        Text(_c.format(selectedTotal),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: GoldenityTypography.fontFamilyMono,
                                color: GoldenityColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GoldenityFillButton(
                      label: 'Bayar Sekarang',
                      icon: Icons.arrow_forward_rounded,
                      color: GoldenityColors.success,
                      onTap: () => _openPayment(selectedOrders),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(height: 1, color: GoldenityColors.border),
            const SizedBox(height: 10),
            _row('Total Pesanan', '${d.orderCount} order'),
            _row('Belum Dibayar', '${d.unpaidCount} order'),
            _row('Grand Total', _c.format(d.grandTotal), bold: true),
            _row('Sisa Tagihan', _c.format(d.unpaidTotal),
                color: d.unpaidTotal > 0 ? GoldenityColors.error : GoldenityColors.success),
            const SizedBox(height: 14),
            if (d.unpaidCount > 0 && _selected.isEmpty) ...[
              GoldenityFillButton(
                label: 'Bayar Semua Tagihan — ${_c.format(d.unpaidTotal)}',
                icon: Icons.payments_rounded,
                onTap: () => _openPayment(settleable),
              ),
              const SizedBox(height: 8),
            ],
            if (d.unpaidCount > 0)
              GoldenityOutlineButton(
                label: 'Tutup Sesi Meja',
                icon: Icons.lock_outline_rounded,
                onTap: _closing ? null : _closeSession,
              )
            else
              GoldenityFillButton(
                label: 'Tutup Sesi Meja',
                icon: Icons.event_available_rounded,
                color: GoldenityColors.warning,
                busy: _closing,
                onTap: _closeSession,
              ),
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

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.order,
    required this.currency,
    required this.selected,
    this.onToggle,
  });
  final WebOrderInSession order;
  final NumberFormat currency;
  final bool selected;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final paid = order.isPaid;
    final cancelled = order.isCancelled;
    final time =
        order.createdAt != null ? DateFormat('HH:mm').format(order.createdAt!.toLocal()) : '';
    final subColor = paid
        ? GoldenityColors.success
        : order.isPendingVerification
            ? GoldenityColors.warning
            : GoldenityColors.muted;
    return Opacity(
      opacity: cancelled ? 0.55 : 1,
      child: Material(
        color: selected ? GoldenityColors.primaryLight : GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              border: Border.all(
                color: selected ? GoldenityColors.primary : GoldenityColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _box(paid: paid, selected: selected, selectable: onToggle != null),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text('Q-${order.queueNumber}',
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          _tag(order.orderStatusLabel, GoldenityColors.primaryLight,
                              GoldenityColors.primary),
                          const Spacer(),
                          Text(currency.format(order.total),
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: GoldenityTypography.fontFamilyMono)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order.payMethodLabel}${time.isNotEmpty ? ' · $time' : ''} · ${order.payStatusLabel}',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w600, color: subColor),
                      ),
                      const SizedBox(height: 5),
                      for (final it in order.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text('${it.qty}× ${it.productName}',
                              style: const TextStyle(
                                  fontSize: 11, color: GoldenityColors.text2)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _box({required bool paid, required bool selected, required bool selectable}) {
    if (paid) {
      return const Icon(Icons.check_circle_rounded, size: 20, color: GoldenityColors.success);
    }
    if (!selectable) {
      return const Icon(Icons.remove_circle_outline_rounded,
          size: 20, color: GoldenityColors.textXMuted);
    }
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? GoldenityColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected ? GoldenityColors.primary : GoldenityColors.border2,
          width: 1.6,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _tag(String t, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(GoldenityRadius.xs)),
        child: Text(t, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
      );
}

/// Modal pembayaran meja — selesaikan 1..N web order sekaligus (split bill).
class _TablePaymentDialog extends ConsumerStatefulWidget {
  const _TablePaymentDialog({
    required this.tableId,
    required this.tableCode,
    required this.orders,
    required this.currency,
  });
  final String tableId;
  final String tableCode;
  final List<WebOrderInSession> orders;
  final NumberFormat currency;

  @override
  ConsumerState<_TablePaymentDialog> createState() => _TablePaymentDialogState();
}

class _TablePaymentDialogState extends ConsumerState<_TablePaymentDialog> {
  String _method = 'CASH';
  final _cashCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  NumberFormat get _c => widget.currency;
  num get _total => widget.orders.fold<num>(0, (s, o) => s + o.total);
  num get _cash => num.tryParse(_cashCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  num get _change => _cash - _total;
  bool get _cashOk => _method != 'CASH' || _cash >= _total;

  @override
  void dispose() {
    _cashCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  List<num> get _quickAmounts {
    final t = _total;
    num ceilTo(num step) => (t % step == 0) ? t : ((t ~/ step) + 1) * step;
    final set = <num>{t, ceilTo(50000), ceilTo(100000), ceilTo(100000) + 100000};
    final list = set.where((v) => v >= t).toList()..sort();
    return list;
  }

  Future<void> _confirm() async {
    if (!_cashOk) {
      setState(() => _error = 'Nominal tunai kurang dari total tagihan.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(tableListProvider.notifier).settleOrders(
            widget.tableId,
            orderIds: widget.orders.map((o) => o.id).toList(),
            paymentMethod: _method,
            cashReceived: _method == 'CASH' ? _cash : null,
            paymentReferenceNumber: _method == 'CASH' ? null : _refCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(res);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 420,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.86),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GoldenityColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 60, offset: Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pembayaran — ${widget.orders.length} Pesanan',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
                        const SizedBox(height: 2),
                        Text('Meja ${widget.tableCode}',
                            style: const TextStyle(fontSize: 12, color: GoldenityColors.muted)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _busy ? null : () => Navigator.of(context).maybePop(),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.close_rounded, size: 18, color: GoldenityColors.muted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final o in widget.orders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: GoldenityColors.surface2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: GoldenityColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Text('Q-${o.queueNumber}',
                                        style: const TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w800)),
                                    const Spacer(),
                                    Text(_c.format(o.total),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            fontFamily: GoldenityTypography.fontFamilyMono)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                for (final it in o.items)
                                  Text('${it.qty}× ${it.productName}',
                                      style: const TextStyle(
                                          fontSize: 11, color: GoldenityColors.text2)),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: GoldenityColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Text('Total Tagihan',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: GoldenityColors.primary)),
                            const Spacer(),
                            Text(_c.format(_total),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: GoldenityTypography.fontFamilyMono,
                                    color: GoldenityColors.primary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Metode Pembayaran',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: GoldenityColors.text2)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _methodBtn('CASH', 'Tunai', Icons.payments_rounded),
                          const SizedBox(width: 8),
                          _methodBtn('QRIS', 'QRIS', Icons.qr_code_2_rounded),
                          const SizedBox(width: 8),
                          _methodBtn('CREDIT_CARD', 'Kartu', Icons.credit_card_rounded),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_method == 'CASH') ...[
                        const Text('Nominal Diterima',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: GoldenityColors.text2)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _cashCtrl,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              fontFamily: GoldenityTypography.fontFamilyMono),
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: GoldenityColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final a in _quickAmounts)
                              _chip(a == _total ? 'Uang pas' : _c.format(a), () {
                                _cashCtrl.text = a.toStringAsFixed(0);
                                setState(() {});
                              }),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_change >= 0 ? 'Kembalian' : 'Kurang',
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: GoldenityColors.text2)),
                            Text(_c.format(_change.abs()),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: GoldenityTypography.fontFamilyMono,
                                  color: _change >= 0
                                      ? GoldenityColors.success
                                      : GoldenityColors.error,
                                )),
                          ],
                        ),
                      ] else ...[
                        const Text('No. Referensi (opsional)',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: GoldenityColors.text2)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _refCtrl,
                          decoration: InputDecoration(
                            hintText: 'mis. kode approval / ID transaksi',
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: GoldenityColors.error)),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GoldenityOutlineButton(
                      label: 'Batal',
                      onTap: _busy ? null : () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: GoldenityFillButton(
                      label: 'Konfirmasi Pembayaran ${_c.format(_total)}',
                      icon: Icons.check_rounded,
                      busy: _busy,
                      onTap: _cashOk ? _confirm : null,
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

  Widget _methodBtn(String value, String label, IconData icon) {
    final active = _method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _method = value;
          _error = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? GoldenityColors.primaryLight : GoldenityColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? GoldenityColors.primary : GoldenityColors.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: active ? GoldenityColors.primary : GoldenityColors.muted),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: active ? GoldenityColors.primary : GoldenityColors.text2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: GoldenityColors.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: GoldenityColors.border),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: GoldenityColors.text2)),
        ),
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
