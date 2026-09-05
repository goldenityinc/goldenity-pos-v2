import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/cashier_shift/screens/cashier_shift_screen.dart';
import '../../../features/dashboard/screens/dashboard_screen.dart';
import '../../../features/finance/screens/finance_screen.dart';
import '../../../features/inventory/screens/category_management_screen.dart';
import '../../../features/inventory/screens/product_list_screen.dart';
import '../../../features/inventory/screens/product_management_list_screen.dart';
import '../../../features/sales/screens/sales_history_screen.dart';
import '../../../features/settings/screens/settings_screen.dart';
import 'goldenity_sidebar.dart';

class GoldenityAppShell extends ConsumerStatefulWidget {
  final GoldenitySidebarTab initialTab;
  const GoldenityAppShell({super.key, this.initialTab = GoldenitySidebarTab.pos});

  @override
  ConsumerState<GoldenityAppShell> createState() => _GoldenityAppShellState();
}

class _GoldenityAppShellState extends ConsumerState<GoldenityAppShell> {
  late GoldenitySidebarTab _currentTab;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: GoldenitySidebar.kWidth,
            child: GoldenitySidebar(
              currentTab: _currentTab,
              onTabChanged: (tab) => setState(() => _currentTab = tab),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: IndexedStack(
              index: _indexOf(_currentTab),
              children: const [
                ProductListScreen(),
                DashboardScreen(),
                SalesHistoryScreen(),
                FinanceScreen(),
                ProductManagementListScreen(),
                CategoryManagementScreen(),
                SettingsScreen(),
                CashierShiftScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _indexOf(GoldenitySidebarTab tab) => switch (tab) {
        GoldenitySidebarTab.pos => 0,
        GoldenitySidebarTab.dashboard => 1,
        GoldenitySidebarTab.salesHistory => 2,
        GoldenitySidebarTab.finance => 3,
        GoldenitySidebarTab.inventory => 4,
        GoldenitySidebarTab.categories => 5,
        GoldenitySidebarTab.settings => 6,
        GoldenitySidebarTab.shift => 7,
      };
}
