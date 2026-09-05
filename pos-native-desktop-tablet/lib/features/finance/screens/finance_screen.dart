import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
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
  DateTimeRange? _range;
  FinanceReportProfile? _report;

  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final DateFormat _dateFormatter = DateFormat.yMd('id_ID');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 30)),
      end: now,
    );
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
      if (_range == null) throw Exception('Range tanggal tidak valid');
      final dashboardApi = ref.read(dashboardApiServiceProvider);
      final isoStart = _range!.start.toIso8601String();
      final isoEnd = _range!.end.toIso8601String();
      final report = await dashboardApi.getFinanceReport(
        authToken: token,
        from: isoStart,
        to: isoEnd,
      );
      if (mounted) {
        setState(() {
          _report = report;
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

  Future<void> _pickDateRange() async {
    if (_range == null) return;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null && mounted) {
      setState(() => _range = picked);
      await _loadData();
    }
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
            Text('Laporan Keuangan', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(
              'Laporan laba rugi & perbandingan',
              style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _pickDateRange,
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Pilih Tanggal',
          ),
          if (_range != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.sm),
              child: Chip(
                backgroundColor: biz.light,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
                label: Text(
                  '${_dateFormatter.format(_range!.start)} — ${_dateFormatter.format(_range!.end)}',
                  style: textTheme.labelSmall?.copyWith(color: biz.dark, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          const SizedBox(width: GoldenitySpacing.xs),
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
              : _report == null
                  ? const SizedBox.shrink()
                  : _buildBody(context, textTheme, biz, _report!),
    );
  }

  Widget _buildBody(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, FinanceReportProfile report) {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: biz.base,
      child: ListView(
        padding: const EdgeInsets.all(GoldenitySpacing.lg),
        children: [
          _buildTotalsCards(textTheme, biz, report.totals),
          const SizedBox(height: GoldenitySpacing.md),
          _buildPaymentBreakdown(context, textTheme, biz, report),
          const SizedBox(height: GoldenitySpacing.md),
          _buildDailyTrend(context, textTheme, biz, report),
        ],
      ),
    );
  }

  Widget _buildTotalsCards(TextTheme textTheme, GoldenityBizColors biz, FinanceReportTotals totals) {
    final cards = [
      ('Pendapatan Kotor', totals.gross, Icons.trending_up_rounded, GoldenityColors.success, GoldenityColors.successLight),
      ('Diskon', totals.discount, Icons.discount_rounded, GoldenityColors.warning, GoldenityColors.warningLight),
      ('Pajak', totals.tax, Icons.receipt_rounded, biz.base, biz.light),
      ('Service Charge', totals.serviceCharge, Icons.room_service_rounded, biz.base, biz.light),
      ('Refund', totals.refund, Icons.money_off_rounded, GoldenityColors.error, GoldenityColors.errorLight),
      ('Pendapatan Bersih', totals.net, Icons.account_balance_rounded, biz.dark, biz.light),
    ];

    return Column(
      children: [
        for (int i = 0; i < cards.length; i += 2)
          Padding(
            padding: EdgeInsets.only(bottom: i + 2 < cards.length ? GoldenitySpacing.sm : 0),
            child: Row(
              children: [
                Expanded(
                  child: _FinanceStatCard(
                    label: cards[i].$1,
                    value: _formatCurrency(cards[i].$2),
                    icon: cards[i].$3,
                    fgColor: cards[i].$4,
                    bgColor: cards[i].$5,
                    textTheme: textTheme,
                  ),
                ),
                const SizedBox(width: GoldenitySpacing.sm),
                Expanded(
                  child: i + 1 < cards.length
                      ? _FinanceStatCard(
                          label: cards[i + 1].$1,
                          value: _formatCurrency(cards[i + 1].$2),
                          icon: cards[i + 1].$3,
                          fgColor: cards[i + 1].$4,
                          bgColor: cards[i + 1].$5,
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

  Widget _buildPaymentBreakdown(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, FinanceReportProfile report) {
    final allMethods = ['CASH', 'QRIS', 'CREDIT_CARD'];
    final byMethod = <String, PaymentBreakdownItem>{};
    for (final item in report.paymentBreakdown) {
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

  Widget _buildDailyTrend(BuildContext context, TextTheme textTheme, GoldenityBizColors biz, FinanceReportProfile report) {
    final sortedTrend = List<DailyTrendItem>.from(report.dailyTrend)
      ..sort((a, b) {
        final da = DateTime.tryParse(a.date);
        final db = DateTime.tryParse(b.date);
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

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
                Icon(Icons.calendar_month_rounded, color: biz.base),
                const SizedBox(width: GoldenitySpacing.sm),
                Expanded(
                  child: Text(
                    'Tren Harian',
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${sortedTrend.length} hari',
                  style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: GoldenityColors.border),
          if (sortedTrend.isEmpty)
            Padding(
              padding: const EdgeInsets.all(GoldenitySpacing.xl),
              child: Center(
                child: Text('Belum ada data tren harian', style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: GoldenitySpacing.xs),
              itemCount: sortedTrend.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: GoldenityColors.border),
              itemBuilder: (context, i) {
                final t = sortedTrend[i];
                final parsedDate = DateTime.tryParse(t.date);
                final dateLabel = parsedDate != null ? _dateFormatter.format(parsedDate) : t.date;
                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: biz.light,
                      borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.today_rounded, color: biz.dark, size: 20),
                  ),
                  title: Text(
                    _formatCurrency(t.grossRevenue),
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, fontFamily: 'RobotoMono', color: biz.dark),
                  ),
                  subtitle: Text(
                    '${t.transactions} transaksi · Refund ${_formatCurrency(t.refund)}',
                    style: textTheme.bodySmall?.copyWith(color: GoldenityColors.text2),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm, vertical: GoldenitySpacing.xs),
                    decoration: BoxDecoration(
                      color: GoldenityColors.surface2,
                      borderRadius: BorderRadius.circular(GoldenityRadius.sm),
                    ),
                    child: Text(
                      dateLabel,
                      style: textTheme.labelSmall?.copyWith(color: GoldenityColors.text2, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _FinanceStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color fgColor;
  final Color bgColor;
  final TextTheme textTheme;

  const _FinanceStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.fgColor,
    required this.bgColor,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(color: fgColor.withValues(alpha: 0.1)),
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
                child: Icon(icon, color: fgColor, size: 20),
              ),
              const SizedBox(width: GoldenitySpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(color: fgColor, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(color: fgColor, fontWeight: FontWeight.w900, fontFamily: 'RobotoMono'),
          ),
        ],
      ),
    );
  }
}
