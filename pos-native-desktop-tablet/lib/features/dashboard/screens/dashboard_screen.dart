import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
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

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

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
      final summary = await dashboardApi.getSummary(authToken: token, range: _range);
      if (mounted) {
        setState(() {
          _summary = summary;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _formatCurrency(num value) {
    return _currencyFormatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    return Scaffold(
      backgroundColor: GoldenityColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Dashboard', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              'Ringkasan penjualan periode ini',
              style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          FilterChip(
            label: const Text('Hari Ini'),
            selected: _range == 'today',
            onSelected: _loading
                ? null
                : (v) {
                    if (v) {
                      setState(() => _range = 'today');
                      _loadData();
                    }
                  },
          ),
          const SizedBox(width: GoldenitySpacing.xs),
          FilterChip(
            label: const Text('Minggu Ini'),
            selected: _range == 'week',
            onSelected: _loading
                ? null
                : (v) {
                    if (v) {
                      setState(() => _range = 'week');
                      _loadData();
                    }
                  },
          ),
          const SizedBox(width: GoldenitySpacing.xs),
          FilterChip(
            label: const Text('Bulan Ini'),
            selected: _range == 'month',
            onSelected: _loading
                ? null
                : (v) {
                    if (v) {
                      setState(() => _range = 'month');
                      _loadData();
                    }
                  },
          ),
          const SizedBox(width: GoldenitySpacing.sm),
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: biz.base,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
          const SizedBox(width: GoldenitySpacing.sm),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(GoldenitySpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: GoldenityColors.error),
                        const SizedBox(height: GoldenitySpacing.md),
                        Text(_errMsg, style: textTheme.bodyMedium),
                        const SizedBox(height: GoldenitySpacing.md),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() => _errMsg = '');
                            _loadData();
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : _summary == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, textTheme, biz, _summary!),
    );
  }

  Widget _buildBody(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, DashboardSummaryProfile summary) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: biz.base,
      child: ListView(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        children: [
          _buildStatCards(textTheme, biz, summary),
          const SizedBox(height: GoldenitySpacing.md),
          _buildTopProducts(context, textTheme, biz, summary),
          const SizedBox(height: GoldenitySpacing.md),
          _buildPaymentBreakdown(context, textTheme, biz, summary),
          const SizedBox(height: GoldenitySpacing.md),
          _buildCategoryBreakdown(context, textTheme, biz, summary),
        ],
      ),
    );
  }

  Widget _buildStatCards(TextTheme textTheme, GoldenityBizColors biz, DashboardSummaryProfile summary) {
    final List<(String, num, IconData)> cards = [
      ('Total Pendapatan', summary.totalRevenue, Icons.payments_rounded),
      ('Total Transaksi', summary.totalTransactions, Icons.receipt_long_rounded),
      ('Rata-rata Transaksi', summary.avgTransaction, Icons.trending_up_rounded),
      ('Pendapatan Bersih', summary.netRevenue, Icons.account_balance_wallet_rounded),
    ];

    return Column(
      children: [
        for (int i = 0; i < cards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < cards.length ? GoldenitySpacing.sm : 0),
            child: Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: cards[i].$1,
                    value: cards[i].$2 is int ? '${cards[i].$2}' : _formatCurrency(cards[i].$2),
                    icon: cards[i].$3,
                    biz: biz,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: GoldenitySpacing.sm),
                Expanded(
                  child: i + 1 < cards.length
                      ? _StatCard(
                          label: cards[i + 1].$1,
                          value: cards[i + 1].$2 is int ? '${cards[i + 1].$2}' : _formatCurrency(cards[i + 1].$2),
                          icon: cards[i + 1].$3,
                          biz: biz,
                          textTheme: textTheme,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTopProducts(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, DashboardSummaryProfile summary) {
    final topProducts = summary.topProducts.take(5).toList();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            child: Row(
              children: [
                Icon(Icons.star_rounded, color: biz.base),
                const SizedBox(width: GoldenitySpacing.sm),
                Text(
                  'Produk Terlaris',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: GoldenityColors.border),
          if (topProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(GoldenitySpacing.xl),
              child: Center(
                child: Text('Belum ada data produk terlaris', style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.xs),
              itemCount: topProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: GoldenityColors.border),
              itemBuilder: (context, i) {
                final p = topProducts[i];
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: i < 3 ? GoldenityColors.warningLight : biz.light,
                      borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: i < 3 ? GoldenityColors.warning : biz.dark,
                      ),
                    ),
                  ),
                  title: Text(
                    p.productName,
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${p.qty} unit terjual',
                    style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                  ),
                  trailing: Text(
                    _formatCurrency(p.total),
                    style: textTheme.titleSmall?.copyWith(color: biz.dark, fontWeight: FontWeight.w800, fontFamily: 'RobotoMono'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdown(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, DashboardSummaryProfile summary) {
    final allMethods = ['CASH', 'QRIS', 'CREDIT_CARD'];
    final byMethod = <String, PaymentBreakdownItem>{};
    for (final item in summary.paymentBreakdown) {
      byMethod[item.paymentMethod] = item;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            child: Row(
              children: [
                Icon(Icons.payment_rounded, color: biz.base),
                const SizedBox(width: GoldenitySpacing.sm),
                Text(
                  'Breakdown Pembayaran',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: GoldenityColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.xs),
            child: Column(
              children: allMethods.map((method) {
                final item = byMethod[method];
                final total = item?.total ?? 0;
                final percent = item?.percent ?? 0;
                final count = item?.count ?? 0;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: biz.light,
                      borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      method == 'CASH'
                          ? Icons.payments_rounded
                          : method == 'QRIS'
                              ? Icons.qr_code_2_rounded
                              : Icons.credit_card_rounded,
                      color: biz.dark,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          method == 'CASH'
                              ? 'Tunai (CASH)'
                              : method == 'QRIS'
                                  ? 'QRIS'
                                  : 'Kartu Kredit',
                          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: GoldenitySpacing.sm),
                      SizedBox(
                        width: 100,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(GoldenityRadius.full),
                          child: LinearProgressIndicator(
                            value: percent / 100,
                            minHeight: 8,
                            backgroundColor: GoldenityColors.surface2,
                            valueColor: AlwaysStoppedAnimation<Color>(biz.base),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '$count transaksi · ${percent.toStringAsFixed(1)}%',
                    style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                  ),
                  trailing: Text(
                    _formatCurrency(total),
                    style: textTheme.titleSmall?.copyWith(color: biz.dark, fontWeight: FontWeight.w800, fontFamily: 'RobotoMono'),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, DashboardSummaryProfile summary) {
    final categories = summary.categoryBreakdown;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: GoldenityColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            child: Row(
              children: [
                Icon(Icons.category_rounded, color: biz.base),
                const SizedBox(width: GoldenitySpacing.sm),
                Text(
                  'Breakdown Kategori',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: GoldenityColors.border),
          Padding(
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            child: categories.isEmpty
                ? Center(
                    child: Text(
                      'Belum ada data kategori',
                      style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                    ),
                  )
                : Wrap(
                    spacing: GoldenitySpacing.sm,
                    runSpacing: GoldenitySpacing.sm,
                    children: categories.map((cat) {
                      return Chip(
                        backgroundColor: biz.light,
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cat.categoryName,
                              style: textTheme.labelSmall?.copyWith(color: biz.dark, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: GoldenitySpacing.xs),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(GoldenityRadius.full),
                              ),
                              child: Text(
                                _formatCurrency(cat.total),
                                style: textTheme.labelSmall?.copyWith(color: biz.base, fontWeight: FontWeight.w900, fontFamily: 'RobotoMono'),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final GoldenityBizColors biz;
  final TextTheme textTheme;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.biz,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: biz.light,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: biz.base.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(GoldenitySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                ),
                child: Icon(icon, color: biz.dark, size: 20),
              ),
              const SizedBox(width: GoldenitySpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(color: biz.dark, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(color: biz.dark, fontWeight: FontWeight.w900, fontFamily: 'RobotoMono'),
          ),
        ],
      ),
    );
  }
}
