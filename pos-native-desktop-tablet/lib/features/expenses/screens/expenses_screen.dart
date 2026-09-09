import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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

// ── Ikon + warna per kategori (match Figma) ──
({IconData icon, Color tint, Color fg}) _catStyle(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.contains('gaji') || n.contains('upah')) {
    return (icon: Icons.badge_rounded, tint: const Color(0xFFF3E8FF), fg: const Color(0xFF7C3AED));
  }
  if (n.contains('sewa')) {
    return (icon: Icons.apartment_rounded, tint: const Color(0xFFE0E7FF), fg: const Color(0xFF4F46E5));
  }
  if (n.contains('utilitas') || n.contains('listrik')) {
    return (icon: Icons.lightbulb_rounded, tint: const Color(0xFFFEF9C3), fg: const Color(0xFFCA8A04));
  }
  if (n.contains('bahan')) {
    return (icon: Icons.shopping_cart_rounded, tint: const Color(0xFFDCFCE7), fg: const Color(0xFF16A34A));
  }
  if (n.contains('marketing') || n.contains('iklan') || n.contains('promo')) {
    return (icon: Icons.campaign_rounded, tint: const Color(0xFFFEE2E2), fg: const Color(0xFFDC2626));
  }
  if (n.contains('perbaikan') || n.contains('perawatan') || n.contains('servis')) {
    return (icon: Icons.build_rounded, tint: const Color(0xFFFFEDD5), fg: const Color(0xFFEA580C));
  }
  if (n.contains('peralatan') || n.contains('aset')) {
    return (icon: Icons.inventory_2_rounded, tint: const Color(0xFFCCFBF1), fg: const Color(0xFF0D9488));
  }
  if (n.contains('lain')) {
    return (icon: Icons.more_horiz_rounded, tint: const Color(0xFFF1F5F9), fg: const Color(0xFF475569));
  }
  return (icon: Icons.settings_rounded, tint: const Color(0xFFF1F5F9), fg: const Color(0xFF475569));
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _fmt = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final _dtFmt = DateFormat('dd MMM yyyy HH:mm', 'id_ID');
  bool _loading = false;
  String _err = '';
  List<Map<String, dynamic>> _cats = const [];
  List<Map<String, dynamic>> _all = const []; // 60 hari terakhir (semua status)
  int _pendingSync = 0;
  Timer? _syncTimer;
  ExpenseOfflineQueue? _queue;
  String _range = 'month'; // today | 7 | month
  String _catFilter = '';
  String _search = '';

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
      final f = DateFormat('yyyy-MM-dd');
      final now = DateTime.now();
      final from = f.format(now.subtract(const Duration(days: 60)));
      final to = f.format(now);
      final results = await Future.wait([
        api.categories(token: token),
        api.list(token: token, from: from, to: to),
      ]);
      if (!mounted) return;
      setState(() {
        _cats = results[0] as List<Map<String, dynamic>>;
        final data = results[1] as Map<String, dynamic>;
        _all = ((data['items'] as List?) ?? const [])
            .map((e) => (e as Map).cast<String, dynamic>())
            .toList();
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
        break;
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

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _inRange(DateTime d) {
    final n = DateTime.now();
    switch (_range) {
      case 'today':
        return _isToday(d);
      case '7':
        return d.isAfter(n.subtract(const Duration(days: 7)));
      default: // month
        return d.year == n.year && d.month == n.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final branch = ref.watch(currentSessionProvider)?.selectedBranch?.name ??
        ref.watch(currentSessionProvider)?.tenant.name ??
        'Cabang';

    // Ringkasan kartu (dari _all = 60 hari).
    int todayTotal = 0, todayCount = 0, monthTotal = 0, monthCount = 0, voided = 0;
    for (final e in _all) {
      final v = e['status'] == 'VOIDED';
      if (v) voided++;
      final amt = (e['amount'] as num?)?.toInt() ?? 0;
      final d = DateTime.tryParse(e['expenseDate']?.toString() ?? '');
      if (d == null || v) continue;
      if (_isToday(d)) {
        todayTotal += amt;
        todayCount++;
      }
      final n = DateTime.now();
      if (d.year == n.year && d.month == n.month) {
        monthTotal += amt;
        monthCount++;
      }
    }

    // Daftar yang tampil = range + kategori + search.
    final s = _search.trim().toLowerCase();
    final list = _all.where((e) {
      final d = DateTime.tryParse(e['expenseDate']?.toString() ?? '');
      if (d == null || !_inRange(d)) return false;
      if (_catFilter.isNotEmpty && e['categoryId'] != _catFilter) return false;
      if (s.isNotEmpty &&
          !('${e['title']} ${e['categoryName']} ${e['expenseNumber']}').toLowerCase().contains(s)) {
        return false;
      }
      return true;
    }).toList();

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
              _syncBanner(),
            // 3 kartu ringkas
            LayoutBuilder(builder: (context, c) {
              final cards = [
                _statCard('Pengeluaran Hari Ini', _fmt.format(todayTotal), '$todayCount transaksi', GoldenityColors.error),
                _statCard('Pengeluaran Bulan Ini', _fmt.format(monthTotal), '$monthCount transaksi aktif', const Color(0xFFEA580C)),
                _statCard('Total Tercatat', '${_all.length} item', '$voided dibatalkan', GoldenityColors.primary),
              ];
              if (c.maxWidth < 720) {
                return Column(children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(height: GoldenitySpacing.sm),
                    cards[i],
                  ],
                ]);
              }
              return Row(children: [
                Expanded(child: cards[0]),
                const SizedBox(width: GoldenitySpacing.sm),
                Expanded(child: cards[1]),
                const SizedBox(width: GoldenitySpacing.sm),
                Expanded(child: cards[2]),
              ]);
            }),
            const SizedBox(height: GoldenitySpacing.md),
            // Filter
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _rangeChip('today', 'Hari Ini'),
                _rangeChip('7', '7 Hari'),
                _rangeChip('month', 'Bulan Ini'),
                _catDropdown(),
                SizedBox(
                  width: 220,
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Cari pengeluaran…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
                    ),
                  ),
                ),
                Text('${list.length} item',
                    style: textTheme.labelSmall?.copyWith(color: GoldenityColors.muted)),
              ],
            ),
            const SizedBox(height: GoldenitySpacing.md),
            if (_err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(_err, style: textTheme.bodyMedium?.copyWith(color: GoldenityColors.error)),
              )
            else if (list.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: Text('Belum ada pengeluaran pada filter ini.',
                    style: TextStyle(color: GoldenityColors.muted))),
              )
            else
              ...list.map((e) => _expenseCard(e, textTheme)),
          ],
        ),
      ),
    );
  }

  Widget _syncBanner() => Container(
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
      );

  Widget _statCard(String label, String value, String sub, Color color) => Container(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
          border: Border.all(color: GoldenityColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10.5, color: GoldenityColors.muted, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: GoldenityColors.muted)),
        ]),
      );

  Widget _rangeChip(String key, String label) => ChoiceChip(
        label: Text(label),
        selected: _range == key,
        onSelected: (_) => setState(() => _range = key),
      );

  Widget _catDropdown() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: GoldenityColors.border),
          borderRadius: BorderRadius.circular(GoldenityRadius.sm),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _catFilter.isEmpty ? '' : _catFilter,
            isDense: true,
            items: [
              const DropdownMenuItem(value: '', child: Text('Semua Kategori')),
              ..._cats.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']?.toString() ?? '-'))),
            ],
            onChanged: (v) => setState(() => _catFilter = v ?? ''),
          ),
        ),
      );

  String _payLabel(String? pm) => switch (pm) {
        'CASH' => 'Tunai (Kas)',
        'TRANSFER' => 'Transfer Bank',
        'QRIS' => 'QRIS',
        'CARD' => 'Kartu',
        _ => pm ?? '-',
      };

  Widget _expenseCard(Map<String, dynamic> e, TextTheme textTheme) {
    final voided = e['status'] == 'VOIDED';
    final amount = (e['amount'] as num?)?.toInt() ?? 0;
    final date = DateTime.tryParse(e['expenseDate']?.toString() ?? '');
    final st = _catStyle(e['categoryName']?.toString());
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
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: st.tint, borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
              child: Icon(st.icon, size: 20, color: st.fg),
            ),
            const SizedBox(width: GoldenitySpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(e['title']?.toString() ?? '-',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                  if (voided) ...[
                    const SizedBox(width: 6),
                    const Text('DIBATALKAN',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: GoldenityColors.error)),
                  ],
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: st.tint, borderRadius: BorderRadius.circular(GoldenityRadius.full)),
                    child: Text(e['categoryName']?.toString() ?? '-',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: st.fg)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${_payLabel(e['paymentMethod']?.toString())}'
                      '${date != null ? ' · ${_dtFmt.format(date)}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: GoldenityColors.muted),
                    ),
                  ),
                  if ((e['attachments'] as List?)?.isNotEmpty ?? false) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.attach_file_rounded, size: 12, color: GoldenityColors.muted),
                  ],
                ]),
              ]),
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('-${_fmt.format(amount)}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: GoldenityColors.error)),
              const SizedBox(height: 2),
              Text(e['createdByName']?.toString() ?? '',
                  style: const TextStyle(fontSize: 10.5, color: GoldenityColors.muted)),
            ]),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 18, color: GoldenityColors.muted),
          ]),
        ),
      ),
    );
  }

  // ─────────────── Form 2 langkah ───────────────
  Future<void> _openForm() async {
    if (_cats.isEmpty) {
      try {
        _cats = await ref.read(expenseApiServiceProvider).categories(token: _token ?? '');
      } catch (_) {}
    }
    if (!mounted) return;
    final branch = ref.read(currentSessionProvider)?.selectedBranch?.name ??
        ref.read(currentSessionProvider)?.tenant.name ??
        'Cabang';
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String catId = _cats.isNotEmpty ? _cats.first['id'] as String : '';
    String pm = 'CASH';
    DateTime date = DateTime.now();
    int step = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final amount = int.tryParse(amountCtrl.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
          final catName = _cats.firstWhere((c) => c['id'] == catId, orElse: () => const {})['name']?.toString() ?? '-';
          return Padding(
            padding: EdgeInsets.only(
              left: GoldenitySpacing.lg,
              right: GoldenitySpacing.lg,
              top: GoldenitySpacing.md,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + GoldenitySpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Center(
                  child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: GoldenityColors.border, borderRadius: BorderRadius.circular(2))),
                ),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Catat Pengeluaran', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text('Cabang $branch', style: const TextStyle(fontSize: 12, color: GoldenityColors.muted)),
                    ]),
                  ),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ]),
                const SizedBox(height: GoldenitySpacing.sm),
                _stepper(step),
                const SizedBox(height: GoldenitySpacing.md),
                if (step == 0) ...[
                  _label('Judul Pengeluaran *'),
                  TextField(controller: titleCtrl, onChanged: (_) => setSheet(() {}),
                      decoration: const InputDecoration(hintText: 'mis. Beli galon & es batu', border: OutlineInputBorder())),
                  const SizedBox(height: GoldenitySpacing.md),
                  _label('Jumlah (Rp) *'),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final digits = v.replaceAll(RegExp(r'\D'), '');
                      final f = digits.isEmpty ? '' : NumberFormat.decimalPattern('id_ID').format(int.parse(digits));
                      amountCtrl.value = TextEditingValue(text: f, selection: TextSelection.collapsed(offset: f.length));
                      setSheet(() {});
                    },
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(prefixText: 'Rp  ', hintText: '0', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  _label('Kategori'),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15,
                    children: _cats.map((c) {
                      final id = c['id'] as String;
                      final st = _catStyle(c['name']?.toString());
                      final sel = catId == id;
                      return InkWell(
                        onTap: () => setSheet(() => catId = id),
                        borderRadius: BorderRadius.circular(GoldenityRadius.md),
                        child: Container(
                          decoration: BoxDecoration(
                            color: sel ? GoldenityColors.primaryLight : Colors.white,
                            borderRadius: BorderRadius.circular(GoldenityRadius.md),
                            border: Border.all(color: sel ? GoldenityColors.primary : GoldenityColors.border, width: sel ? 1.5 : 1),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(st.icon, size: 20, color: st.fg),
                            const SizedBox(height: 4),
                            Text(c['name']?.toString() ?? '-',
                                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, height: 1.15)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  _label('Metode Pembayaran'),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in const [
                      ('CASH', 'Tunai (Kas)', Icons.payments_rounded),
                      ('TRANSFER', 'Transfer Bank', Icons.account_balance_rounded),
                      ('QRIS', 'QRIS', Icons.qr_code_2_rounded),
                      ('CARD', 'Kartu Debit/Kredit', Icons.credit_card_rounded),
                    ])
                      ChoiceChip(
                        avatar: Icon(m.$3, size: 15, color: pm == m.$1 ? Colors.white : GoldenityColors.text2),
                        label: Text(m.$2),
                        selected: pm == m.$1,
                        onSelected: (_) => setSheet(() => pm = m.$1),
                      ),
                  ]),
                  const SizedBox(height: GoldenitySpacing.md),
                  _label('Tanggal'),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: ctx, initialDate: date, firstDate: DateTime(2023), lastDate: DateTime.now());
                      if (picked != null) setSheet(() => date = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today_rounded, size: 16)),
                      child: Text(DateFormat('dd MMM yyyy', 'id_ID').format(date)),
                    ),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  _label('Catatan (opsional)'),
                  TextField(controller: noteCtrl, maxLines: 2,
                      decoration: const InputDecoration(hintText: 'Tambahkan catatan jika perlu…', border: OutlineInputBorder())),
                  const SizedBox(height: GoldenitySpacing.lg),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty || amount <= 0 || catId.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                backgroundColor: GoldenityColors.error,
                                content: Text('Judul, jumlah & kategori wajib diisi.')));
                            return;
                          }
                          setSheet(() => step = 1);
                        },
                        child: const Text('Lanjut →'),
                      ),
                    ),
                  ]),
                ] else ...[
                  // Step 2 — konfirmasi
                  Container(
                    padding: const EdgeInsets.all(GoldenitySpacing.md),
                    decoration: BoxDecoration(
                      color: GoldenityColors.surface2,
                      borderRadius: BorderRadius.circular(GoldenityRadius.md),
                    ),
                    child: Column(children: [
                      _confRow('Judul', titleCtrl.text.trim()),
                      _confRow('Jumlah', _fmt.format(amount)),
                      _confRow('Kategori', catName),
                      _confRow('Metode', _payLabel(pm)),
                      _confRow('Tanggal', DateFormat('dd MMM yyyy', 'id_ID').format(date)),
                      if (noteCtrl.text.trim().isNotEmpty) _confRow('Catatan', noteCtrl.text.trim()),
                    ]),
                  ),
                  const SizedBox(height: GoldenitySpacing.md),
                  const Text('Pastikan data sudah benar. Setelah disimpan, pembatalan perlu peran Admin/Akuntan.',
                      style: TextStyle(fontSize: 12, color: GoldenityColors.muted)),
                  const SizedBox(height: GoldenitySpacing.lg),
                  Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => setSheet(() => step = 0), child: const Text('← Kembali'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _submit({
                            'title': titleCtrl.text.trim(),
                            'amount': amount,
                            'categoryId': catId,
                            'paymentMethod': pm,
                            'note': noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                            'expenseDate': DateFormat('yyyy-MM-dd').format(date),
                            'clientRef': const Uuid().v4(),
                          });
                        },
                        child: const Text('Simpan Pengeluaran'),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
      );

  Widget _stepper(int step) => Row(children: [
        _stepDot('1', 'Detail', step >= 0, step == 0),
        Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 8),
            color: step >= 1 ? GoldenityColors.primary : GoldenityColors.border)),
        _stepDot('2', 'Konfirmasi', step >= 1, step == 1),
      ]);

  Widget _stepDot(String n, String label, bool done, bool active) => Row(children: [
        Container(
          width: 22, height: 22, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? GoldenityColors.primary : GoldenityColors.surface2,
            shape: BoxShape.circle,
          ),
          child: Text(n, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: done ? Colors.white : GoldenityColors.muted)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? GoldenityColors.primary : GoldenityColors.muted)),
      ]);

  Widget _confRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: Text(k, style: const TextStyle(fontSize: 12, color: GoldenityColors.muted))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))),
        ]),
      );

  // ─────────────── Detail + batalkan ───────────────
  Future<void> _openDetail(Map<String, dynamic> e) async {
    final voided = e['status'] == 'VOIDED';
    final st = _catStyle(e['categoryName']?.toString());
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Container(width: 34, height: 34,
              decoration: BoxDecoration(color: st.tint, borderRadius: BorderRadius.circular(GoldenityRadius.sm)),
              child: Icon(st.icon, size: 17, color: st.fg)),
          const SizedBox(width: 10),
          Expanded(child: Text(e['title']?.toString() ?? 'Pengeluaran', style: const TextStyle(fontSize: 15))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _confRow('Nomor', e['expenseNumber']?.toString() ?? '-'),
          _confRow('Jumlah', _fmt.format((e['amount'] as num?)?.toInt() ?? 0)),
          _confRow('Kategori', e['categoryName']?.toString() ?? '-'),
          _confRow('Metode', _payLabel(e['paymentMethod']?.toString())),
          _confRow('Dicatat oleh', e['createdByName']?.toString() ?? '-'),
          if ((e['note']?.toString() ?? '').isNotEmpty) _confRow('Catatan', e['note'].toString()),
          if (voided) _confRow('Alasan batal', e['voidReason']?.toString() ?? '-'),
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

  Future<void> _confirmVoid(Map<String, dynamic> e) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan pengeluaran?'),
        content: TextField(controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Alasan', border: OutlineInputBorder())),
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
      await ref.read(expenseApiServiceProvider).voidExpense(token: token, id: e['id'] as String, reason: reasonCtrl.text.trim());
      _snack('Pengeluaran dibatalkan', ok: true);
      await _load();
    } catch (err) {
      _snack(err.toString().replaceAll('Exception: ', ''), ok: false);
    }
  }
}
