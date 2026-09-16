import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_constants.dart';
import '../../core/config/storage_keys.dart';
import '../../core/design/goldenity_colors.dart';
import '../../core/services/android_fg_weborder_handler.dart';
import '../../features/auth/providers/auth_provider.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Auto-start Android FG Web-Order Receiver SETELAH shell mount (after
      // auth) — sebelumnya cuma bisa dinyalakan manual lewat toggle di
      // Settings, jadi tidak auto-resume setelah login/restart app seperti
      // di pos-native-desktop-tablet. Logic sama persis dgn
      // goldenity_app_shell.dart._GoldenityAppShellState.initState.
      final session = ref.read(currentSessionProvider);
      if (session == null) return;
      final sp = await SharedPreferences.getInstance();
      await ApiConstants.initialize(sp);
      if (Platform.isAndroid) {
        final enabled = sp.getBool(StorageKeys.fgServiceEnabled) ?? false;
        if (enabled) {
          bool running = false;
          try {
            running = await FlutterForegroundTask.isRunningService;
          } catch (_) {}
          if (!running) {
            try {
              await _startFgWebOrderService();
            } catch (_) {}
          }
        }
      }
    });
  }

  Future<void> _startFgWebOrderService() async {
    if (!Platform.isAndroid) return;
    // Lihat komentar sama di settings_screen.dart._initAndStartFgService —
    // tanpa ini, notifikasi persisten (+ suara/getar order baru) diam-diam
    // tidak pernah muncul kalau service ini start duluan sebelum izin ada.
    final notifStatus = await FlutterForegroundTask.checkNotificationPermission();
    if (notifStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    FlutterForegroundTask.init(
      androidNotificationOptions: androidNotificationOptionsForWebOrderFg(),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    await FlutterForegroundTask.startService(
      notificationTitle: 'Goldenity POS',
      notificationText: 'Menerima pesanan web secara otomatis di latar belakang.',
      notificationIcon: const NotificationIcon(metaDataName: 'launcher_icon'),
      callback: startFgWebOrderCallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final biz = Theme.of(context).extension<GoldenityBizColors>() ??
        GoldenityBizColors.fnb;

    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
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
