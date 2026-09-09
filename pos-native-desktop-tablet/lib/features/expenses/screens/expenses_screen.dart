import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../shared/widgets/goldenity_page_header.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/expense_offline_queue.dart';
import '../services/expense_api_service.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dateFmt = DateFormat('d MMM', 'id_ID');
  bool _loading = false;
  String _err = '';
  List<Map<String, dynamic>> _cats = const [];
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _summary = const {};
  int _pendingSync = 0;
  Timer? _syncTimer;
  ExpenseOfflineQueue? _queue;
  String _range = '7'; // 7 | 30 | month

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _queue = await ExpenseOfflineQueue.open();
      await _flushQueue();
      await _load();
      _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) => _flushQueue());
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  ({DateTime from, DateTime to}) _rangeDates() {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
    switch (_range) {
      case '30':
        return (from: to.subtract(const Duration(days: 29)), to: to);
      case 'month':
        return (from: DateTime(now.year, now.month, 1), to: to);
      default:
        return (from: to.subtract(const Duration(days: 6)), to: to);
    }
  }

  String? get _token => ref.read(authNotifierProvider.notifier).session?.token;

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _err = '';
    });
    try {
      final api = ref.read(expenseApiServiceProvider);
      final r = _rangeDates();
      final f = DateFormat('yyyy-MM-dd');
      final results = await Future.wait([
        api.categories(token: token),
        api.list(token: token, from: f.format(r.from), to: f.format(r.to)),
      ]);
      if (!mounted) return;
      setState(() {
        _cats = results[0] as List<Map<String, dynamic>>;
        final data = results[1] as Map<String, dynamic>;
        _items = ((data['items'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
        _summary = (data['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
      });
    } catch (e) {
      if (mounted) setState(() => _err = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _flushQueue() async {
    final q = _queue;
    final token = _token;
    if (q == null || token == null) return;
    final ready = q.getReady();
    if (ready.isEmpty) {
      if (mounted && _pendingSync != q.pendingCount) setState(() => _pendingSync = q.pendingCount);
      return;
    }
    final api = ref.read(expenseApiServiceProvider);
    for (final e in ready) {
      final ref0 = e['clientRef'] as String;
      try {
        await api.create(token: token, payload: (e['payload'] as Map).cast<String, dynamic>());
        await q.dequeue(ref0);
      } on SocketException {
        break; // masih offline
      } on TimeoutException {
        break;
      } catch (err) {
        await q.markRetry(ref0, err.toString());
      }
    }
    if (mounted) {
      setState(() => _pendingSync = q.pendingCount);
      await _load();
    }
  }

  Future<void> _submit(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null) return;
    final api = ref.read(expenseApiServiceProvider);
    try {
      await api.create(token: token, payload: payload);
      _snack('Pengeluaran dicatat', ok: true);
    } on SocketException {
      await _queue?.enqueue(clientRef: payload['clientRef'] as String, payload: payload, lastError: 'offline');
      _snack('Offline — disimpan lokal, akan disinkron otomatis', ok: true);
    } on TimeoutException {
      await _queue?.enqueue(clientRef: payload['clientRef'] as String, payload: payload, lastError: 'timeout');
      _snack('Koneksi lambat — disimpan lokal, akan disinkron otomatis', ok: true);
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), ok: false);
      return;
    }
    if (mounted) setState(() => _pendingSync = _queue?.pendingCount ?? 0);
    await _load();
  }

  void _snack(String m, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: ok ? GoldenityColors.success : GoldenityColors.error,
      content: Text(m),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final total = (_summary['total'] as num?)?.toInt() ?? 0;
    final avg = (_summary['avgPerDay'] as num?)?.toInt() ?? 0;
    final count = (_summary['count'] as num?)?.toInt() ?? 0;
    final branch = ref.watch(currentSessionProvider)?.selectedBranch?.name ??
        ref.watch(currentSessionProvider)?.tenant.name ??
        'Cabang';

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: GoldenityColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: GoldenityPageHeader(
          title: 'Pengeluaran',
          subtitle: 'Catat & pantau pengeluaran kas — Cabang $branch',
          dense: true,
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
          Padding(
            padding: const EdgeInsets.only(right: GoldenitySpacing.md, top: 8, bottom: 8),
            child: GoldenityPrimaryButton(
              label: 'Catat Pengeluaran',
              icon: Icons.add_rounded,
              height: 40,
              onPressed: _openForm,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(GoldenitySpacing.lg),
          children: [
            if (_pendingSync > 0)
              Container(
                margin: const EdgeInsets.only(bottom: GoldenitySpacing.md),
                padding: const EdgeInsets.all(GoldenitySpacing.sm),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEFCE8),
                  borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(children: [
                  const Icon(Icons.sync_rounded, size: 15, color: Color(0xFF854D0E)),
                  const SizedBox(width: 6),
                  Text('$_pendingSync pengeluaran menunggu sinkron',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF854D0E), fontWeight: FontWeight.w600)),
                ]),
              ),
            Row(children: [
              _statCard('Total periode', _fmt.format(total), GoldenityColors.error),
              const SizedBox(width: GoldenitySpacing.sm),
              _statCard('Rata-rata / hari', _fmt.format(avg), GoldenityColors.primary),
              const SizedBox(width: GoldenitySpacing.sm),
              _statCard('Jumlah', '$count', GoldenityColors.text2),
            ]),
            const SizedBox(height: GoldenitySpacing.md),
            Wrap(spacing: 8, children: [
              _rangeChip('7', '7 Hari'),
              _rangeChip('30', '30 Hari'),
              _rangeChip('month', 'Bulan Ini'),
            ]),
            const SizedBox(height: GoldenitySpacing.md),
            if (_err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(_err, style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.error)),
              )
            else if (_items.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Text('Belum ada pengeluaran pada periode ini.',
                      style: TextStyle(color: GoldenityColors.muted)),
                ),
              )
            else
              ..._items.map(_expenseCard),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(GoldenitySpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            border: Border.all(color: GoldenityColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 11, color: GoldenityColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );

  Widget _rangeChip(String key, String label) {
    final sel = _range == key;
    return ChoiceChip(
      label: Text(label),
      selected: sel,
      onSelected: (_) {
        setState(() => _range = key);
        _load();
      },
    );
  }

  Widget _expenseCard(Map<String, dynamic> e) {
    final voided = e['status'] == 'VOIDED';
    final amount = (e['amount'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse(e['expenseDate']?.toString() ?? '');
    return Opacity(
      opacity: voided ? 0.5 : 1,
      child: InkWell(
        onTap: () => _openDetail(e),
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        child: Container(
          margin: const EdgeInsets.only(bottom: GoldenitySpacing.sm),
          padding: const EdgeInsets.all(GoldenitySpacing.md),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
            border: Border.all(color: GoldenityColors.border),
          ),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: GoldenityColors.surface2,
                borderRadius: BorderRadius.circular(GoldenityRadius.sm),
              ),
              child: const Icon(Icons.payments_rounded, size: 18, color: GoldenityColors.text2),
            ),
            const SizedBox(width: GoldenitySpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(e['title']?.toString() ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                  if (voided) ...[
                    const SizedBox(width: 6),
                    const Text('DIBATALKAN',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: GoldenityColors.error)),
                  ],
                  if ((e['attachments'] as List?)?.isNotEmpty ?? false) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.attach_file_rounded, size: 13, color: GoldenityColors.muted),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  '${e['categoryName'] ?? '-'} · ${_payLabel(e['paymentMethod']?.toString())}'
                  '${date != null ? ' · ${_dateFmt.format(date)}' : ''}',
                  style: const TextStyle(fontSize: 11.5, color: GoldenityColors.muted),
                ),
              ]),
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            Text('- ${_fmt.format(amount)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GoldenityColors.error)),
          ]),
        ),
      ),
    );
  }

  String _payLabel(String? pm) => switch (pm) {
        'CASH' => 'Tunai',
        'TRANSFER' => 'Transfer',
        'QRIS' => 'QRIS',
        'CARD' => 'Kartu',
        _ => pm ?? '-',
      };

  // ─────────────── Form catat pengeluaran ───────────────
  Future<void> _openForm() async {
    if (_cats.isEmpty) {
      try {
        _cats = await ref.read(expenseApiServiceProvider).categories(token: _token ?? '');
      } catch (_) {}
    }
    if (!mounted) return;
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String catId = _cats.isNotEmpty ? _cats.first['id'] as String : '';
    String pm = 'CASH';
    DateTime date = DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: GoldenitySpacing.lg,
            right: GoldenitySpacing.lg,
            top: GoldenitySpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + GoldenitySpacing.lg,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Catat Pengeluaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: GoldenitySpacing.md),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Judul Pengeluaran', border: OutlineInputBorder()),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Jumlah (Rp)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: catId.isEmpty ? null : catId,
              decoration: const InputDecoration(labelText: 'Kategori', border: OutlineInputBorder()),
              items: _cats
                  .map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']?.toString() ?? '-')))
                  .toList(),
              onChanged: (v) => setSheet(() => catId = v ?? catId),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: pm,
              decoration: const InputDecoration(labelText: 'Metode Pembayaran', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Tunai (Kas)')),
                DropdownMenuItem(value: 'TRANSFER', child: Text('Transfer')),
                DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                DropdownMenuItem(value: 'CARD', child: Text('Kartu')),
              ],
              onChanged: (v) => setSheet(() => pm = v ?? pm),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: date,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setSheet(() => date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Tanggal', border: OutlineInputBorder()),
                child: Text(DateFormat('d MMMM yyyy', 'id_ID').format(date)),
              ),
            ),
            const SizedBox(height: GoldenitySpacing.sm),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: GoldenitySpacing.md),
            Row(children: [
              Expanded(
                child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final amount = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (title.isEmpty || amount <= 0 || catId.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          backgroundColor: GoldenityColors.error,
                          content: Text('Judul, jumlah & kategori wajib diisi.')));
                      return;
                    }
                    Navigator.pop(ctx);
                    _submit({
                      'title': title,
                      'amount': amount,
                      'categoryId': catId,
                      'paymentMethod': pm,
                      'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      'expenseDate': DateFormat('yyyy-MM-dd').format(date),
                      'clientRef': const Uuid().v4(),
                    });
                  },
                  child: const Text('Simpan'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ─────────────── Detail + batalkan ───────────────
  Future<void> _openDetail(Map<String, dynamic> e) async {
    final voided = e['status'] == 'VOIDED';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e['title']?.toString() ?? 'Pengeluaran'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _dRow('Nomor', e['expenseNumber']?.toString() ?? '-'),
          _dRow('Jumlah', _fmt.format((e['amount'] as num?)?.toInt() ?? 0)),
          _dRow('Kategori', e['categoryName']?.toString() ?? '-'),
          _dRow('Metode', _payLabel(e['paymentMethod']?.toString())),
          _dRow('Dicatat oleh', e['createdByName']?.toString() ?? '-'),
          if ((e['note']?.toString() ?? '').isNotEmpty) _dRow('Catatan', e['note'].toString()),
          if (voided) _dRow('Alasan batal', e['voidReason']?.toString() ?? '-'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          if (!voided)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmVoid(e);
              },
              child: const Text('Batalkan', style: TextStyle(color: GoldenityColors.error)),
            ),
        ],
      ),
    );
  }

  Widget _dRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(k, style: const TextStyle(fontSize: 12, color: GoldenityColors.muted))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );

  Future<void> _confirmVoid(Map<String, dynamic> e) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pengeluaran?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: 'Alasan', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Batalkan')),
        ],
      ),
    );
    if (ok != true) return;
    final token = _token;
    if (token == null) return;
    if (reasonCtrl.text.trim().length < 3) {
      _snack('Alasan wajib diisi (min 3 huruf).', ok: false);
      return;
    }
    try {
      await ref.read(expenseApiServiceProvider).voidExpense(
            token: token,
            id: e['id'] as String,
            reason: reasonCtrl.text.trim(),
          );
      _snack('Pengeluaran dibatalkan', ok: true);
      await _load();
    } catch (err) {
      _snack(err.toString().replaceAll('Exception: ', ''), ok: false);
    }
  }
}
