import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/goldenity_colors.dart';
import '../../features/inventory/screens/product_list_screen.dart';
import '../../features/profile/screens/profile_mobile_screen.dart';
import '../../features/web_orders/screens/web_orders_screen.dart';
import '../../features/sales/screens/sales_history_screen.dart';
import '../../features/inventory/screens/product_management_list_screen.dart';

class GoldenityMobileShell extends ConsumerStatefulWidget {
  const GoldenityMobileShell({
    super.key,
    this.initialTab = 0,
    required this.onTabChange,
    this.webOrderBadge = 0,
    required this.userFullName,
    required this.branchName,
  });

  final int initialTab;
  final void Function(int idx) onTabChange;
  final int webOrderBadge;
  final String userFullName;
  final String branchName;

  @override
  ConsumerState<GoldenityMobileShell> createState() =>
      _GoldenityMobileShellState();
}

class _GoldenityMobileShellState extends ConsumerState<GoldenityMobileShell> {
  late int _tab = widget.initialTab;

  final List<Widget> _screens = const [
    ProductListScreen(),
    WebOrdersScreen(),
    SalesHistoryScreen(),
    ProductManagementListScreen(),
    ProfileMobileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final biz = Theme.of(context).extension<GoldenityBizColors>() ??
        GoldenityBizColors.fnb;

    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        backgroundColor: GoldenityColors.surface,
        indicatorColor: biz.base.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          widget.onTabChange(i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Penjualan',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${widget.webOrderBadge}'),
              isLabelVisible: widget.webOrderBadge > 0,
              child: const Icon(Icons.delivery_dining_rounded),
            ),
            label: 'Web Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Riwayat',
          ),
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Inventaris',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
