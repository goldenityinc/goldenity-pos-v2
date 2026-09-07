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

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _loading = false;
  String _errMsg = '';
  String _range = 'today';
  DashboardSummaryProfile? _summary;

  final NumberFormat _currency =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  static const int _lowStockThreshold = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
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
      final dashboardApi = ref.read(dashboardApiServiceProvider);
      final summary =
          await dashboardApi.getSummary(authToken: token, range: _range);
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) {
        setState(() => _errMsg = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(num v) => _currency.format(v);

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 19) return 'Selamat sore';
    return 'Selamat malam';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errMsg.isNotEmpty
              ? _ErrorState(message: _errMsg, onRetry: _loadData)
              : _summary == null
                  ? const SizedBox.shrink()
                  : _buildBody(_summary!),
    );
  }

  Widget _buildBody(DashboardSummaryProfile s) {
    final session = ref.watch(currentSessionProvider);
    final username = session?.user.username ?? 'Kasir';
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(now);

    final products = ref.watch(productListNotifierProvider).products;
    final lowStock = products
        .where((p) => p.isActive && p.stock <= _lowStockThreshold)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    return RefreshIndicator(
      onRefresh: _loadData,
      color: GoldenityColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        children: [
          // ── Header: greeting + shift badge ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_greeting()}, $username! 👋',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: GoldenityColors.text)),
                    const SizedBox(height: 4),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 13, color: GoldenityColors.muted)),
                  ],
                ),
              ),
              _RangeTabs(
                value: _range,
                onChanged: _loading
                    ? null
                    : (v) {
                        setState(() => _range = v);
                        _loadData();
                      },
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.md),
          // ── Status row ──
          const Wrap(
            spacing: GoldenitySpacing.sm,
            runSpacing: GoldenitySpacing.sm,
            children: [
              _StatusPill(
                  icon: Icons.circle,
                  iconColor: GoldenityColors.success,
                  label: 'Online'),
              _StatusPill(
                  icon: Icons.cloud_done_rounded,
                  iconColor: GoldenityColors.muted,
                  label: 'Tersinkron'),
              _StatusPill(
                  icon: Icons.print_rounded,
                  iconColor: GoldenityColors.muted,
                  label: 'Printer OK'),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.lg),
          // ── KPI row ──
          _KpiRow(children: [
            _KpiCard(label: 'PENDAPATAN', value: _fmt(s.totalRevenue)),
            _KpiCard(
                label: 'TRANSAKSI', value: '${s.totalTransactions}'),
            _KpiCard(
                label: 'RATA-RATA TRANSAKSI', value: _fmt(s.avgTransaction)),
            _KpiCard(label: 'PENDAPATAN BERSIH', value: _fmt(s.netRevenue)),
          ]),
          const SizedBox(height: GoldenitySpacing.lg),
          // ── Two columns: payment summary + top products ──
          LayoutBuilder(
            builder: (context, c) {
              final twoCol = c.maxWidth >= 900;
              final left = _PaymentSummaryCard(summary: s, fmt: _fmt);
              final right = _TopProductsCard(summary: s, fmt: _fmt);
              if (!twoCol) {
                return Column(children: [
                  left,
                  const SizedBox(height: GoldenitySpacing.md),
                  right,
                ]);
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: left),
                    const SizedBox(width: GoldenitySpacing.md),
                    Expanded(flex: 2, child: right),
                  ],
                ),
              );
            },
          ),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: GoldenitySpacing.lg),
            _LowStockStrip(
              items: lowStock,
              label: (p) => p.stock <= 0
                  ? '${p.name} · habis'
                  : '${p.name} · ${p.stock} tersisa',
            ),
          ],
          const SizedBox(height: GoldenitySpacing.lg),
          _CategoryBreakdownCard(summary: s, fmt: _fmt),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Range tabs (Hari Ini / Minggu Ini / Bulan Ini)
// ────────────────────────────────────────────────────────────
class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String>? onChanged;

  static const _opts = [
    ('today', 'Hari Ini'),
    ('week', 'Minggu Ini'),
    ('month', 'Bulan Ini'),
  ];

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
        children: _opts.map((o) {
          final active = o.$1 == value;
          return GestureDetector(
            onTap: onChanged == null ? null : () => onChanged!(o.$1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? GoldenityColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(GoldenityRadius.md),
              ),
              child: Text(o.$2,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : GoldenityColors.muted,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.icon, required this.iconColor, required this.label});
  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.full),
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: GoldenityColors.text2)),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// KPI cards
// ────────────────────────────────────────────────────────────
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final perRow = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
      const gap = GoldenitySpacing.md;
      final w = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: w, child: child),
        ],
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});
  final String label;
  final String value;

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
              style: const TextStyle(
                fontFamily: GoldenityTypography.fontFamilyMono,
                fontFeatures: [FontFeature.tabularFigures()],
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                color: GoldenityColors.text,
              )),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Shared card shell (matches Figma: white, radius 12, border, pad 20)
// ────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

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
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: GoldenityColors.text)),
          ),
          const Divider(height: 1, color: GoldenityColors.border),
          Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  const _PaymentSummaryCard({required this.summary, required this.fmt});
  final DashboardSummaryProfile summary;
  final String Function(num) fmt;

  static const _methods = [
    ('CASH', 'Tunai'),
    ('QRIS', 'QRIS'),
    ('CREDIT_CARD', 'Kartu'),
  ];

  @override
  Widget build(BuildContext context) {
    final byMethod = {for (final i in summary.paymentBreakdown) i.paymentMethod: i};
    return _Card(
      title: 'Ringkasan Pembayaran',
      child: Column(
        children: [
          for (final m in _methods) ...[
            _row(
              m.$2,
              byMethod[m.$1]?.count ?? 0,
              (byMethod[m.$1]?.percent ?? 0).toDouble(),
              byMethod[m.$1]?.total ?? 0,
            ),
            if (m != _methods.last) const SizedBox(height: GoldenitySpacing.md),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, int count, double percent, num total) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: GoldenityColors.text)),
        ),
        const SizedBox(width: GoldenitySpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(GoldenityRadius.full),
                child: LinearProgressIndicator(
                  value: (percent / 100).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: GoldenityColors.surface2,
                  valueColor: const AlwaysStoppedAnimation<Color>(GoldenityColors.primary),
                ),
              ),
              const SizedBox(height: 4),
              Text('$count transaksi · ${percent.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: GoldenityColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: GoldenitySpacing.sm),
        Text(fmt(total),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: GoldenityColors.text,
              fontFamily: GoldenityTypography.fontFamilyMono,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.summary, required this.fmt});
  final DashboardSummaryProfile summary;
  final String Function(num) fmt;

  @override
  Widget build(BuildContext context) {
    final top = summary.topProducts.take(5).toList();
    return _Card(
      title: 'Produk Terlaris',
      child: top.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: GoldenitySpacing.lg),
              child: Center(
                child: Text('Belum ada data',
                    style: TextStyle(color: GoldenityColors.muted, fontSize: 13)),
              ),
            )
          : Column(
              children: [
                for (int i = 0; i < top.length; i++) ...[
                  Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: GoldenityColors.primaryLight,
                          borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                        ),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: GoldenityColors.primary)),
                      ),
                      const SizedBox(width: GoldenitySpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(top[i].productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: GoldenityColors.text)),
                            Text('${top[i].qty} terjual',
                                style: const TextStyle(
                                    fontSize: 11, color: GoldenityColors.muted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: GoldenitySpacing.sm),
                      Text(fmt(top[i].total),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: GoldenityColors.text,
                            fontFamily: GoldenityTypography.fontFamilyMono,
                            fontFeatures: [FontFeature.tabularFigures()],
                          )),
                    ],
                  ),
                  if (i != top.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: GoldenitySpacing.sm),
                      child: Divider(height: 1, color: GoldenityColors.border),
                    ),
                ],
              ],
            ),
    );
  }
}

class _LowStockStrip extends StatelessWidget {
  const _LowStockStrip({required this.items, required this.label});
  final List<dynamic> items;
  final String Function(dynamic) label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GoldenitySpacing.md),
      decoration: BoxDecoration(
        color: GoldenityColors.warningLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(GoldenityRadius.xl),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 15, color: GoldenityColors.warning),
              SizedBox(width: 6),
              Text('Peringatan Stok Rendah',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: GoldenityColors.warning)),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final it in items.take(12))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: GoldenityColors.surface,
                    borderRadius: BorderRadius.circular(GoldenityRadius.md),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Text(label(it),
                      style: const TextStyle(fontSize: 12.5, color: GoldenityColors.text)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdownCard extends StatelessWidget {
  const _CategoryBreakdownCard({required this.summary, required this.fmt});
  final DashboardSummaryProfile summary;
  final String Function(num) fmt;

  @override
  Widget build(BuildContext context) {
    final cats = summary.categoryBreakdown;
    return _Card(
      title: 'Breakdown Kategori',
      child: cats.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: GoldenitySpacing.md),
              child: Center(
                child: Text('Belum ada data kategori',
                    style: TextStyle(color: GoldenityColors.muted, fontSize: 13)),
              ),
            )
          : Wrap(
              spacing: GoldenitySpacing.sm,
              runSpacing: GoldenitySpacing.sm,
              children: [
                for (final c in cats)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: GoldenityColors.surface2,
                      borderRadius: BorderRadius.circular(GoldenityRadius.md),
                      border: Border.all(color: GoldenityColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(c.categoryName,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: GoldenityColors.text)),
                        const SizedBox(width: 6),
                        Text(fmt(c.total),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: GoldenityColors.primary,
                              fontFamily: GoldenityTypography.fontFamilyMono,
                              fontFeatures: [FontFeature.tabularFigures()],
                            )),
                      ],
                    ),
                  ),
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
