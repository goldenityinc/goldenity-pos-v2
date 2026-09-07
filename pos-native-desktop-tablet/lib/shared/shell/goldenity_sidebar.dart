import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../widgets/goldenity_modal.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/models/shift_profile.dart';
import '../../../core/models/tenant_profile.dart';
import '../../../core/models/user_profile.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/inventory/providers/product_list_provider.dart';

enum GoldenitySidebarTab {
  pos,
  dashboard,
  salesHistory,
  finance,
  inventory,
  categories,
  tables,
  webOrders,
  shift,
  settings,
}

const _navActiveText = Color(0xFF60A5FA);
const _navActiveBorder = Color(0xFF3B82F6);

class GoldenitySidebar extends ConsumerWidget {
  const GoldenitySidebar({
    super.key,
    this.currentTab = GoldenitySidebarTab.pos,
    this.onTabChanged,
    this.tableBadge = 0,
    this.webOrderBadge = 0,
  });

  final GoldenitySidebarTab currentTab;
  final ValueChanged<GoldenitySidebarTab>? onTabChanged;
  final int tableBadge;
  final int webOrderBadge;

  static const double kWidth = GoldenityLayout.sidebarWidth; // 200

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(currentSessionProvider);

    return Container(
      width: kWidth,
      decoration: const BoxDecoration(color: GoldenityColors.sidebar),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _brandHeader(textTheme, session?.tenant),
          const SizedBox(height: GoldenitySpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: GoldenitySpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _nav(Icons.storefront_rounded, 'Point of Sale', GoldenitySidebarTab.pos),
                  _nav(Icons.grid_view_rounded, 'Dashboard', GoldenitySidebarTab.dashboard),
                  _nav(Icons.receipt_long_rounded, 'Riwayat Penjualan', GoldenitySidebarTab.salesHistory),
                  _nav(Icons.account_balance_wallet_rounded, 'Keuangan', GoldenitySidebarTab.finance),
                  _nav(Icons.inventory_2_rounded, 'Daftar Produk', GoldenitySidebarTab.inventory),
                  _nav(Icons.sell_rounded, 'Kategori Produk', GoldenitySidebarTab.categories),
                  _nav(Icons.table_restaurant_rounded, 'Manajemen Meja', GoldenitySidebarTab.tables, badge: tableBadge),
                  _nav(Icons.delivery_dining_rounded, 'Web Orders', GoldenitySidebarTab.webOrders, badge: webOrderBadge),
                  _nav(Icons.timelapse_rounded, 'Shift Kasir', GoldenitySidebarTab.shift),
                  _nav(Icons.settings_rounded, 'Pengaturan', GoldenitySidebarTab.settings),
                  const SizedBox(height: GoldenitySpacing.md),
                  _bizMode(textTheme),
                ],
              ),
            ),
          ),
          _homeLink(textTheme),
          _userFooter(context, textTheme, ref, session?.user, session),
          const SizedBox(height: GoldenitySpacing.md),
        ],
      ),
    );
  }

  // ── Brand ────────────────────────────────────────────────
  Widget _brandHeader(TextTheme t, TenantProfile? tenant) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GoldenitySpacing.md, GoldenitySpacing.lg, GoldenitySpacing.md, GoldenitySpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: GoldenityColors.primary,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
            ),
            child: const Text('G',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5)),
          ),
          const SizedBox(width: GoldenitySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('Goldenity',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: -0.2)),
                const SizedBox(height: 1),
                Text('POS V2 · F&B',
                    style: t.labelSmall?.copyWith(
                        color: GoldenityColors.sidebarText, fontWeight: FontWeight.w600, letterSpacing: 0.03)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Nav item ─────────────────────────────────────────────
  Widget _nav(IconData icon, String label, GoldenitySidebarTab tab, {int badge = 0}) {
    final active = currentTab == tab;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GoldenityRadius.md),
          onTap: onTabChanged == null ? null : () => onTabChanged!(tab),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: active ? GoldenityColors.sidebarActive : Colors.transparent,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
              border: Border(
                left: BorderSide(
                    color: active ? _navActiveBorder : Colors.transparent, width: 3),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(icon,
                    size: 17, color: active ? _navActiveText : GoldenityColors.sidebarText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: active ? _navActiveText : GoldenityColors.sidebarText,
                      )),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                        color: GoldenityColors.warning, borderRadius: BorderRadius.circular(GoldenityRadius.full)),
                    child: Text('$badge',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Biz mode ─────────────────────────────────────────────
  Widget _bizMode(TextTheme t) {
    Widget item(IconData icon, String label, {required bool active}) {
      final fg = active ? Colors.white : GoldenityColors.sidebarText.withValues(alpha: 0.55);
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
              const Spacer(),
              if (active)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: GoldenityColors.warning, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Text('MODE BISNIS',
              style: t.labelSmall?.copyWith(
                  color: GoldenityColors.sidebarText.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.08,
                  fontSize: 10)),
        ),
        item(Icons.restaurant_rounded, 'F&B', active: true),
        item(Icons.shopping_bag_rounded, 'Retail', active: false),
        item(Icons.build_rounded, 'Bengkel', active: false),
      ],
    );
  }

  Widget _homeLink(TextTheme t) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Row(
        children: <Widget>[
          Icon(Icons.arrow_back_rounded, size: 13, color: GoldenityColors.sidebarText),
          SizedBox(width: 6),
          Text('Kembali ke Home',
              style: TextStyle(fontSize: 11, color: GoldenityColors.sidebarText, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── User footer ──────────────────────────────────────────
  Widget _userFooter(
    BuildContext context,
    TextTheme t,
    WidgetRef ref,
    UserProfile? user,
    AuthSession? session,
  ) {
    final role = user?.role;
    final isCashier = role == UserRole.CASHIER;
    final isAdmin = role == UserRole.TENANT_ADMIN || role == UserRole.SUPER_ADMIN;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x14FFFFFF),
          borderRadius: BorderRadius.circular(GoldenityRadius.xl),
          border: Border.all(color: const Color(0x1FFFFFFF)),
        ),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 16,
              backgroundColor: GoldenityColors.primary,
              child: Text(user?.username.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
            const SizedBox(width: GoldenitySpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(user?.username ?? 'User',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  const SizedBox(height: 1),
                  FutureBuilder<ShiftProfile?>(
                    future: () async {
                      final token = ref.read(authNotifierProvider.notifier).session?.token;
                      if (token == null) return null;
                      try {
                        return ref.read(shiftApiServiceProvider).getCurrentShift(authToken: token);
                      } catch (_) {
                        return null;
                      }
                    }(),
                    builder: (context, snap) {
                      final loading = snap.connectionState == ConnectionState.waiting;
                      final shift = snap.data;
                      String sub;
                      if (loading) {
                        sub = 'Memuat…';
                      } else if (shift != null) {
                        sub = 'Kasir · Shift Pagi (${DateFormat.Hm().format(shift.openedAt)})';
                      } else if (isCashier) {
                        sub = 'Kasir · Belum Buka Shift';
                      } else if (isAdmin) {
                        sub = 'Admin';
                      } else {
                        sub = role?.name.replaceAll('_', ' ') ?? 'CASHIER';
                      }
                      return Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: GoldenityColors.sidebarText, fontWeight: FontWeight.w600, fontSize: 10.5));
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 16, color: GoldenityColors.sidebarText),
              tooltip: 'Logout',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showGoldenityDialog<bool>(
      context: context,
      title: 'Konfirmasi Logout',
      primaryLabel: 'Ya, Logout',
      primaryColor: GoldenityColors.error,
      child: const Text('Anda yakin ingin keluar dari sesi ini?',
          style: TextStyle(fontSize: 13.5, color: GoldenityColors.text2, height: 1.4)),
      onPrimary: () async {
        ref.read(authNotifierProvider.notifier).logout();
        return true;
      },
    );
  }
}
