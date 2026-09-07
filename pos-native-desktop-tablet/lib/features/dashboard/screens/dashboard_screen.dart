import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/design/goldenity_typography.dart';
import '../../../core/models/dashboard_profile.dart';
import '../../../shared/widgets/goldenity_metric_card.dart';
import '../../../shared/widgets/goldenity_page_header.dart';
import '../../../shared/widgets/goldenity_section_card.dart';
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

  final NumberFormat _currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

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

  String _formatCurrency(num value) => _currencyFormatter.format(value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    return Scaffold(
      backgroundColor: GoldenityColors.bg,
      appBar: AppBar(
        backgroundColor: GoldenityColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const GoldenityPageHeader(
          title: 'Dashboard',
          subtitle: 'Ringkasan penjualan periode ini',
          dense: true,
        ),
        actions: [
          for (final entry in const [
            ('today', 'Hari Ini'),
            ('week', 'Minggu Ini'),
            ('month', 'Bulan Ini'),
          ]) ...[
            ChoiceChip(
              label: Text(entry.$2),
              selected: _range == entry.$1,
              onSelected: _loading
                  ? null
                  : (v) {
                      if (v) {
                        setState(() => _range = entry.$1);
                        _loadData();
                      }
                    },
            ),
            const SizedBox(width: GoldenitySpacing.xs),
          ],
          const SizedBox(width: GoldenitySpacing.xs),
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: _loading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: biz.base),
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
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: GoldenityColors.error),
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

  Widget _buildBody(BuildContext context, TextTheme textTheme,
      GoldenityBizColors biz, DashboardSummaryProfile summary) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: biz.base,
      child: ListView(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        children: [
          _buildStatCards(biz, summary),
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

  Widget _buildStatCards(
      GoldenityBizColors biz, DashboardSummaryProfile summary) {
    final cards = <(String, num, IconData, Color, Color, bool)>[
      ('Total Pendapatan', summary.totalRevenue, Icons.payments_rounded,
          GoldenityColors.successLight, GoldenityColors.success, false),
      ('Total Transaksi', summary.totalTransactions,
          Icons.receipt_long_rounded, GoldenityColors.primaryLight,
          GoldenityColors.primary, true),
      ('Rata-rata Transaksi', summary.avgTransaction,
          Icons.trending_up_rounded, GoldenityColors.warningLight,
          GoldenityColors.warning, false),
      ('Pendapatan Bersih', summary.netRevenue,
          Icons.account_balance_wallet_rounded, biz.light, biz.base, false),
    ];

    return Column(
      children: [
        for (int i = 0; i < cards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
                bottom: i + 2 < cards.length ? GoldenitySpacing.md : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _metricFor(cards[i])),
                const SizedBox(width: GoldenitySpacing.md),
                Expanded(
                  child: i + 1 < cards.length
                      ? _metricFor(cards[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _metricFor((String, num, IconData, Color, Color, bool) c) {
    return GoldenityMetricCard(
      label: c.$1,
      value: c.$6 ? '${c.$2}' : _formatCurrency(c.$2),
      icon: c.$3,
      iconBackground: c.$4,
      iconColor: c.$5,
    );
  }

  Widget _buildTopProducts(BuildContext context, TextTheme textTheme,
      GoldenityBizColors biz, DashboardSummaryProfile summary) {
    final topProducts = summary.topProducts.take(5).toList();
    return GoldenitySectionCard(
      title: 'Produk Terlaris',
      icon: Icons.star_rounded,
      iconColor: GoldenityColors.warning,
      iconBackground: GoldenityColors.warningLight,
      padding: EdgeInsets.zero,
      child: topProducts.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(GoldenitySpacing.xl),
              child: Center(
                child: Text('Belum ada data produk terlaris',
                    style: textTheme.bodySmall
                        ?.copyWith(color: GoldenityColors.muted)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(vertical: GoldenitySpacing.xs),
              itemCount: topProducts.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: GoldenityColors.border),
              itemBuilder: (context, i) {
                final p = topProducts[i];
                return ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i < 3
                          ? GoldenityColors.warningLight
                          : biz.light,
                      borderRadius:
                          BorderRadius.circular(GoldenityRadius.sm),
                    ),
                    child: Text('${i + 1}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: i < 3
                              ? GoldenityColors.warning
                              : biz.dark,
                        )),
                  ),
                  title: Text(p.productName,
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text('${p.qty} unit terjual',
                      style: textTheme.bodySmall?.copyWith(
                          color: GoldenityColors.muted,
                          fontWeight: FontWeight.w600)),
                  trailing: Text(
                    _formatCurrency(p.total),
                    style: textTheme.titleSmall?.copyWith(
                        color: biz.dark,
                        fontWeight: FontWeight.w800,
                        fontFamily: GoldenityTypography.fontFamilyMono),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPaymentBreakdown(BuildContext context, TextTheme textTheme,
      GoldenityBizColors biz, DashboardSummaryProfile summary) {
    const allMethods = ['CASH', 'QRIS', 'CREDIT_CARD'];
    final byMethod = <String, PaymentBreakdownItem>{};
    for (final item in summary.paymentBreakdown) {
      byMethod[item.paymentMethod] = item;
    }

    return GoldenitySectionCard(
      title: 'Breakdown Pembayaran',
      icon: Icons.payment_rounded,
      iconColor: GoldenityColors.primary,
      iconBackground: GoldenityColors.primaryLight,
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
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: biz.light,
                borderRadius: BorderRadius.circular(GoldenityRadius.sm),
              ),
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
                    style: textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: GoldenitySpacing.sm),
                SizedBox(
                  width: 120,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(GoldenityRadius.full),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 8,
                      backgroundColor: GoldenityColors.surface2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(biz.base),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '$count transaksi · ${percent.toStringAsFixed(1)}%',
              style: textTheme.bodySmall?.copyWith(
                  color: GoldenityColors.muted,
                  fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              _formatCurrency(total),
              style: textTheme.titleSmall?.copyWith(
                  color: biz.dark,
                  fontWeight: FontWeight.w800,
                  fontFamily: GoldenityTypography.fontFamilyMono),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryBreakdown(BuildContext context, TextTheme textTheme,
      GoldenityBizColors biz, DashboardSummaryProfile summary) {
    final categories = summary.categoryBreakdown;
    return GoldenitySectionCard(
      title: 'Breakdown Kategori',
      icon: Icons.category_rounded,
      iconColor: biz.dark,
      iconBackground: biz.light,
      child: categories.isEmpty
          ? Center(
              child: Text('Belum ada data kategori',
                  style: textTheme.bodySmall
                      ?.copyWith(color: GoldenityColors.muted)),
            )
          : Wrap(
              spacing: GoldenitySpacing.sm,
              runSpacing: GoldenitySpacing.sm,
              children: categories.map((cat) {
                return Chip(
                  backgroundColor: biz.light,
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                      horizontal: GoldenitySpacing.sm),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat.categoryName,
                          style: textTheme.labelSmall?.copyWith(
                              color: biz.dark,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: GoldenitySpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: GoldenitySpacing.sm, vertical: 2),
                        decoration: BoxDecoration(
                          color: GoldenityColors.surface,
                          borderRadius:
                              BorderRadius.circular(GoldenityRadius.full),
                        ),
                        child: Text(
                          _formatCurrency(cat.total),
                          style: textTheme.labelSmall?.copyWith(
                              color: biz.base,
                              fontWeight: FontWeight.w900,
                              fontFamily:
                                  GoldenityTypography.fontFamilyMono),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
