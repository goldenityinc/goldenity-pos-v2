import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/cashier_shift/screens/cashier_shift_screen.dart';
import '../../../features/dashboard/screens/dashboard_screen.dart';
import '../../../features/finance/screens/finance_screen.dart';
import '../../../features/inventory/screens/category_management_screen.dart';
import '../../../features/inventory/screens/product_list_screen.dart';
import '../../../features/inventory/screens/product_management_list_screen.dart';
import '../../../features/sales/providers/sales_sync_notifier.dart';
import '../../../features/sales/screens/sales_history_screen.dart';
import '../../../features/settings/screens/settings_screen.dart';
import '../../../features/tables/screens/table_management_screen.dart';
import '../../../features/web_orders/screens/web_orders_screen.dart';
import 'goldenity_sidebar.dart';

class GoldenityAppShell extends ConsumerStatefulWidget {
  const GoldenityAppShell({super.key, this.initialTab = GoldenitySidebarTab.pos});
  final GoldenitySidebarTab initialTab;

  @override
  ConsumerState<GoldenityAppShell> createState() => _GoldenityAppShellState();
}

class _GoldenityAppShellState extends ConsumerState<GoldenityAppShell> {
  late GoldenitySidebarTab _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  static const _tabOrder = <GoldenitySidebarTab>[
    GoldenitySidebarTab.pos,
    GoldenitySidebarTab.dashboard,
    GoldenitySidebarTab.salesHistory,
    GoldenitySidebarTab.finance,
    GoldenitySidebarTab.inventory,
    GoldenitySidebarTab.categories,
    GoldenitySidebarTab.tables,
    GoldenitySidebarTab.webOrders,
    GoldenitySidebarTab.shift,
    GoldenitySidebarTab.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final webBadge = ref.watch(salesSyncNotifierProvider).pendingCount;
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GoldenitySidebar(
            currentTab: _tab,
            webOrderBadge: webBadge,
            onTabChanged: (t) => setState(() => _tab = t),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Expanded(
                  child: IndexedStack(
                    index: _tabOrder.indexOf(_tab),
                    children: const <Widget>[
                      ProductListScreen(),
                      DashboardScreen(),
                      SalesHistoryScreen(),
                      FinanceScreen(),
                      ProductManagementListScreen(),
                      CategoryManagementScreen(),
                      TableManagementScreen(),
                      WebOrdersScreen(),
                      CashierShiftScreen(),
                      SettingsScreen(),
                    ],
                  ),
                ),
                const _ShellFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bar tipis di dasar shell — Figma: bg `#F8FAFC`, borderTop `#E2E8F0`, h≈28.
/// Kiri: "Goldenity POS V2 · v{versi}". Kanan: device + status koneksi + sync.
class _ShellFooter extends ConsumerWidget {
  const _ShellFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final deviceLabel = session?.user.username ?? 'Device';
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.lg),
      decoration: const BoxDecoration(
        color: GoldenityColors.surface2,
        border: Border(top: BorderSide(color: GoldenityColors.border)),
      ),
      child: Row(
        children: <Widget>[
          const Text('Goldenity POS V2 · v2.0.0',
              style: TextStyle(fontSize: 10.5, color: GoldenityColors.muted, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          const Text('·', style: TextStyle(fontSize: 10.5, color: GoldenityColors.disabled)),
          const SizedBox(width: 8),
          Text('$deviceLabel · Kasir',
              style: const TextStyle(fontSize: 10.5, color: GoldenityColors.muted, fontWeight: FontWeight.w500)),
          const Spacer(),
          const _StatusDot(color: GoldenityColors.success),
          const SizedBox(width: 5),
          const Text('Online',
              style: TextStyle(fontSize: 10.5, color: GoldenityColors.success, fontWeight: FontWeight.w700)),
          const SizedBox(width: 12),
          Text('Sinkron ${TimeOfDay.now().format(context)}',
              style: const TextStyle(fontSize: 10.5, color: GoldenityColors.muted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
