import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../core/models/dashboard_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../../inventory/providers/product_list_provider.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  bool _loading = false;
  String _errMsg = '';
  String _range = 'month'; // today | week | month
  int _view = 0; // 0 = Laba/Rugi, 1 = Neraca
  FinanceReportProfile? _report;

  final NumberFormat _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  DateTimeRange _rangeFor(String key) {
    final now = DateTime.now();
    switch (key) {
      case 'today':
        return DateTimeRange(start: DateTime(now.year, now.month, now.day), end: now);
      case 'week':
        return DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
      case 'month':
      default:
        return DateTimeRange(start: now.subtract(const Duration(days: 29)), end: now);
    }
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
      final branchId = auth.session?.selectedBranchId ?? auth.session?.user.branchId;
      final r = _rangeFor(_range);
      final report = await ref.read(dashboardApiServiceProvider).getFinanceReport(
            authToken: token,
            from: r.start.toIso8601String(),
            to: r.end.toIso8601String(),
            branchId: branchId,
          );
      if (mounted) setState(() => _report = report);
    } catch (e) {
      if (mounted) {
        setState(() => _errMsg = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(num v) => _currency.format(v);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errMsg.isNotEmpty
              ? _ErrorState(message: _errMsg, onRetry: _loadData)
              : ListView(
                  padding: const EdgeInsets.all(GoldenitySpacing.lg),
                  children: [
                    // ── Header + view toggle ──
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Keuangan',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: GoldenityColors.text)),
                        ),
                        _Segmented(
                          options: const ['Laba/Rugi', 'Neraca'],
                          index: _view,
                          onChanged: (i) => setState(() => _view = i),
                        ),
                      ],
                    ),
                    const SizedBox(height: GoldenitySpacing.md),
                    _RangeTabs(
                      value: _range,
                      onChanged: _loading
                          ? null
                          : (v) {
                              setState(() => _range = v);
                              _loadData();
                            },
                    ),
                    const SizedBox(height: GoldenitySpacing.lg),
                    if (_view == 1)
                      const _Placeholder(
                        icon: Icons.account_balance_rounded,
                        text: 'Neraca akan tersedia setelah modul aset & kewajiban aktif.',
                      )
                    else if (_report == null)
                      const SizedBox.shrink()
                    else
                      ..._labaRugi(_report!),
                  ],
                ),
    );
  }

  List<Widget> _labaRugi(FinanceReportProfile r) {
    final t = r.totals;
    final potongan = t.discount + t.tax + t.serviceCharge + t.refund;
    return [
      // ── KPI cards ──
      _KpiRow(children: [
        _KpiCard(label: 'PENDAPATAN KOTOR', value: _fmt(t.gross)),
        _KpiCard(label: 'TOTAL POTONGAN', value: _fmt(potongan)),
        _KpiCard(label: 'PENDAPATAN BERSIH', value: _fmt(t.net), accent: GoldenityColors.success),
      ]),
      const SizedBox(height: GoldenitySpacing.lg),
      _TrendCard(trend: r.dailyTrend, fmt: _fmt),
      const SizedBox(height: GoldenitySpacing.lg),
      LayoutBuilder(builder: (context, c) {
        final twoCol = c.maxWidth >= 860;
        final left = _IncomeTable(report: r, fmt: _fmt);
        final right = _DeductionTable(totals: t, fmt: _fmt);
        if (!twoCol) {
          return Column(children: [left, const SizedBox(height: GoldenitySpacing.md), right]);
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: left),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(child: right),
            ],
          ),
        );
      }),
    ];
  }
}

// ────────────────────────────────────────────────────────────
class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.index, required this.onChanged});
  final List<String> options;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: GoldenityColors.surface2,
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: i == index ? GoldenityColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                ),
                child: Text(options[i],
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: i == index ? Colors.white : GoldenityColors.muted,
                    )),
              ),
            ),
        ],
      ),
    );
  }
}

class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;

  static const _opts = [('today', 'Hari Ini'), ('week', 'Minggu Ini'), ('month', 'Bulan Ini')];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final o in _opts) ...[
          GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(o.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: o.$1 == value ? GoldenityColors.primary : GoldenityColors.surface,
                borderRadius: BorderRadius.circular(GoldenityRadius.full),
                border: Border.all(
                    color: o.$1 == value ? GoldenityColors.primary : GoldenityColors.border),
              ),
              child: Text(o.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: o.$1 == value ? Colors.white : GoldenityColors.muted,
                  )),
            ),
          ),
          const SizedBox(width: GoldenitySpacing.xs),
        ],
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth >= 760 ? children.length : (c.maxWidth >= 460 ? 2 : 1);
      const gap = GoldenitySpacing.md;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final ch in children) SizedBox(width: w, child: ch)],
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.04,
                color: GoldenityColors.muted,
              )),
          const SizedBox(height: GoldenitySpacing.sm),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: GoldenityTypography.fontFamilyMono,
                fontFeatures: const [FontFeature.tabularFigures()],
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: accent ?? GoldenityColors.text,
              )),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: GoldenityElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GoldenitySpacing.lg, GoldenitySpacing.md, GoldenitySpacing.lg, GoldenitySpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1, color: GoldenityColors.border),
          Padding(padding: const EdgeInsets.all(GoldenitySpacing.md), child: child),
        ],
      ),
    );
  }
}

/// Mini bar chart tren harian pendapatan kotor.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend, required this.fmt});
  final List<DailyTrendItem> trend;
  final String Function(num) fmt;

  @override
  Widget build(BuildContext context) {
    final sorted = List<DailyTrendItem>.from(trend)
      ..sort((a, b) {
        final da = DateTime.tryParse(a.date), db = DateTime.tryParse(b.date);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
    final maxVal = sorted.fold<num>(0, (m, e) => e.grossRevenue > m ? e.grossRevenue : m);
    return _Card(
      title: 'Tren Pendapatan',
      trailing: Text('${sorted.length} hari',
          style: const TextStyle(fontSize: 11, color: GoldenityColors.muted, fontWeight: FontWeight.w600)),
      child: sorted.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: GoldenitySpacing.lg),
              child: Center(
                  child: Text('Belum ada data tren',
                      style: TextStyle(color: GoldenityColors.muted, fontSize: 13))),
            )
          : SizedBox(
              height: 132,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final t in sorted)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              height: maxVal <= 0
                                  ? 2
                                  : (100 * (t.grossRevenue / maxVal)).clamp(2, 100).toDouble(),
                              decoration: BoxDecoration(
                                color: GoldenityColors.primary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _IncomeTable extends StatelessWidget {
  const _IncomeTable({required this.report, required this.fmt});
  final FinanceReportProfile report;
  final String Function(num) fmt;

  static const _methods = [('CASH', 'Tunai'), ('QRIS', 'QRIS'), ('CREDIT_CARD', 'Kartu')];

  @override
  Widget build(BuildContext context) {
    final byMethod = {for (final i in report.paymentBreakdown) i.paymentMethod: i};
    final total = report.paymentBreakdown.fold<num>(0, (s, e) => s + e.total);
    return _Card(
      title: 'Rincian Pendapatan',
      child: Column(
        children: [
          const _TableHead(['SUMBER', 'JUMLAH', '%']),
          for (final m in _methods)
            _TableRow(
              m.$2,
              fmt(byMethod[m.$1]?.total ?? 0),
              '${(byMethod[m.$1]?.percent ?? 0).toStringAsFixed(0)}%',
            ),
          const Divider(height: 12, color: GoldenityColors.border),
          _TableRow('Total', fmt(total), '100%', bold: true),
        ],
      ),
    );
  }
}

class _DeductionTable extends StatelessWidget {
  const _DeductionTable({required this.totals, required this.fmt});
  final FinanceReportTotals totals;
  final String Function(num) fmt;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, num)>[
      ('Diskon', totals.discount),
      ('Pajak (PPN)', totals.tax),
      ('Service Charge', totals.serviceCharge),
      ('Refund', totals.refund),
    ];
    final total = rows.fold<num>(0, (s, e) => s + e.$2);
    return _Card(
      title: 'Rincian Potongan',
      child: Column(
        children: [
          const _TableHead(['SUMBER', 'JUMLAH', '%']),
          for (final r in rows)
            _TableRow(
              r.$1,
              fmt(r.$2),
              total <= 0 ? '0%' : '${(r.$2 / total * 100).toStringAsFixed(0)}%',
            ),
          const Divider(height: 12, color: GoldenityColors.border),
          _TableRow('Total', fmt(total), '100%', bold: true),
        ],
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead(this.labels);
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: _h(labels[0])),
          Expanded(flex: 3, child: _h(labels[1], end: true)),
          Expanded(flex: 1, child: _h(labels[2], end: true)),
        ],
      ),
    );
  }

  Widget _h(String s, {bool end = false}) => Text(s,
      textAlign: end ? TextAlign.right : TextAlign.left,
      style: const TextStyle(
          fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.05, color: GoldenityColors.muted));
}

class _TableRow extends StatelessWidget {
  const _TableRow(this.label, this.amount, this.pct, {this.bold = false});
  final String label;
  final String amount;
  final String pct;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final w = bold ? FontWeight.w800 : FontWeight.w600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label,
                style: TextStyle(fontSize: 12.5, fontWeight: w, color: GoldenityColors.text)),
          ),
          Expanded(
            flex: 3,
            child: Text(amount,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: w,
                  color: GoldenityColors.text,
                  fontFamily: GoldenityTypography.fontFamilyMono,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          Expanded(
            flex: 1,
            child: Text(pct,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11.5, color: GoldenityColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GoldenitySpacing.xl),
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: GoldenityColors.disabled),
          const SizedBox(height: GoldenitySpacing.md),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: GoldenityColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GoldenitySpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 44, color: GoldenityColors.error),
            const SizedBox(height: GoldenitySpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: GoldenitySpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
