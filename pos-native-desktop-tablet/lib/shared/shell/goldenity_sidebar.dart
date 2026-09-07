import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/auth_session.dart';
import '../../../core/models/shift_profile.dart';
import '../../../core/models/tenant_profile.dart';
import '../../../core/models/user_profile.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../features/inventory/providers/product_list_provider.dart';
import '../widgets/goldenity_primary_button.dart';

enum GoldenitySidebarTab {
  pos,
  dashboard,
  salesHistory,
  finance,
  inventory,
  categories,
  settings,
  shift,
}

class GoldenitySidebar extends ConsumerWidget {
  const GoldenitySidebar({
    super.key,
    this.currentTab = GoldenitySidebarTab.pos,
    this.onTabChanged,
  });

  final GoldenitySidebarTab currentTab;
  final ValueChanged<GoldenitySidebarTab>? onTabChanged;

  static const double kWidth = 200;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final session = ref.watch(currentSessionProvider);
    final tenant = session?.tenant;
    final user = session?.user;

    return Container(
      width: kWidth,
      decoration: const BoxDecoration(
        color: GoldenityColors.sidebar,
        border: Border(
          right: BorderSide(color: Color(0x331E293B), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBrandHeader(textTheme, tenant),
          const SizedBox(height: GoldenitySpacing.md),
          _buildBizModeSegmented(textTheme),
          const SizedBox(height: GoldenitySpacing.md),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildNavItem(
                    textTheme,
                    icon: Icons.storefront_rounded,
                    label: 'Point of Sale',
                    tab: GoldenitySidebarTab.pos,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.pos)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xs),
                  _buildNavItem(
                    textTheme,
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    tab: GoldenitySidebarTab.dashboard,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.dashboard)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xs),
                  _buildNavItem(
                    textTheme,
                    icon: Icons.receipt_long_rounded,
                    label: 'Riwayat Penjualan',
                    tab: GoldenitySidebarTab.salesHistory,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.salesHistory)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xs),
                  _buildNavItem(
                    textTheme,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Keuangan',
                    tab: GoldenitySidebarTab.finance,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.finance)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xs),
                  _buildNavItem(
                    textTheme,
                    icon: Icons.inventory_2_rounded,
                    label: 'Daftar Produk',
                    tab: GoldenitySidebarTab.inventory,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.inventory)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xs),
                  _buildNavItem(
                    textTheme,
                    icon: Icons.label_rounded,
                    label: 'Kategori Produk',
                    tab: GoldenitySidebarTab.categories,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.categories)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xs),
                  _buildNavItem(
                    textTheme,
                    icon: Icons.settings_rounded,
                    label: 'Pengaturan',
                    tab: GoldenitySidebarTab.settings,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.settings)
                        : null,
                  ),
                  const SizedBox(height: GoldenitySpacing.xs),
                  _buildNavItem(
                    textTheme,
                    icon: Icons.receipt_long_rounded,
                    label: 'Shift Kasir',
                    tab: GoldenitySidebarTab.shift,
                    onTap: onTabChanged != null
                        ? () => onTabChanged!(GoldenitySidebarTab.shift)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          _buildUserFooter(context, textTheme, ref, user, session),
          const SizedBox(height: GoldenitySpacing.md),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(TextTheme textTheme, TenantProfile? tenant) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GoldenitySpacing.lg,
        GoldenitySpacing.xl,
        GoldenitySpacing.lg,
        GoldenitySpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: GoldenityColors.primary,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
            ),
            alignment: Alignment.center,
            child: Text(
              'G',
              style: textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: GoldenitySpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Goldenity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'POS V2',
                  style: textTheme.labelSmall?.copyWith(
                    color: GoldenityColors.primaryLight,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBizModeSegmented(TextTheme textTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MODE BISNIS',
            style: textTheme.labelSmall?.copyWith(
              color: GoldenityColors.sidebarText,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          _buildBizModeItem(
            textTheme,
            icon: Icons.restaurant_rounded,
            label: 'F&B',
            selected: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBizModeItem(
    TextTheme textTheme, {
    required IconData icon,
    required String label,
    required bool selected,
  }) {
    final bg = selected ? GoldenityColors.warning : Colors.transparent;
    final fg = selected ? Colors.white : GoldenityColors.sidebarText;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        onTap: selected ? null : () {},
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GoldenitySpacing.md,
            vertical: GoldenitySpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: GoldenitySpacing.sm),
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    TextTheme textTheme, {
    required IconData icon,
    required String label,
    required GoldenitySidebarTab tab,
    VoidCallback? onTap,
  }) {
    final isActive = currentTab == tab;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(GoldenityRadius.lg),
          onTap: onTap ?? () => onTabChanged?.call(tab),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: GoldenitySpacing.md,
              vertical: GoldenitySpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(GoldenityRadius.lg),
              color: isActive
                  ? GoldenityColors.primary.withValues(alpha: 0.18)
                  : Colors.transparent,
              border: Border.all(
                color: isActive
                    ? GoldenityColors.primary.withValues(alpha: 0.40)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? Colors.white : GoldenityColors.sidebarText,
                ),
                const SizedBox(width: GoldenitySpacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: isActive ? Colors.white : GoldenityColors.sidebarText,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserFooter(
    BuildContext context,
    TextTheme textTheme,
    WidgetRef ref,
    UserProfile? user,
    AuthSession? session,
  ) {
    final userRole = user?.role;
    final isCashier = userRole == UserRole.CASHIER;
    final isAdmin = userRole == UserRole.TENANT_ADMIN || userRole == UserRole.SUPER_ADMIN;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GoldenitySpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(GoldenitySpacing.md),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(GoldenityRadius.xl),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: GoldenityColors.primary,
                  child: Text(
                    (user?.username.substring(0, 1).toUpperCase() ?? 'U'),
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: GoldenitySpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.username ?? 'User',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FutureBuilder<ShiftProfile?>(
                        future: () async {
                          final auth = ref.read(authNotifierProvider.notifier);
                          final token = auth.session?.token;
                          if (token == null) return null;
                          try {
                            return ref
                                .read(shiftApiServiceProvider)
                                .getCurrentShift(authToken: token);
                          } catch (_) {
                            return null;
                          }
                        }(),
                        builder: (context, snapshot) {
                          final loading =
                              snapshot.connectionState == ConnectionState.waiting;
                          final shift = snapshot.data;
                          String subtitle;
                          if (loading) {
                            subtitle = isCashier ? 'Kasir · Memuat shift...' : 'Memuat...';
                          } else if (shift != null) {
                            final timeStr = DateFormat.Hm().format(shift.openedAt);
                            subtitle = 'Kasir · Shift Pagi ($timeStr)';
                          } else if (isCashier) {
                            subtitle = 'Kasir · Belum Buka Shift';
                          } else if (isAdmin) {
                            subtitle = 'Admin';
                          } else {
                            subtitle = user?.role.name.replaceAll('_', ' ') ?? 'CASHIER';
                          }
                          return Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: GoldenityColors.sidebarText,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: GoldenitySpacing.sm),
          GoldenityPrimaryButton(
            label: 'Logout',
            icon: Icons.logout_rounded,
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GoldenityRadius.xl)),
                  title: const Text('Konfirmasi Logout'),
                  content: const Text('Anda yakin ingin keluar dari sesi ini?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        ref.read(authNotifierProvider.notifier).logout();
                      },
                      child: const Text('Ya, Logout'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
