import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../core/models/branch_profile.dart';
import '../providers/auth_provider.dart';

class BranchSelectionScreen extends ConsumerStatefulWidget {
  const BranchSelectionScreen({super.key});

  @override
  ConsumerState<BranchSelectionScreen> createState() =>
      _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends ConsumerState<BranchSelectionScreen> {
  String? _errorMsg;

  Future<void> _onPick(BranchProfile branch) async {
    setState(() => _errorMsg = null);
    try {
      await ref
          .read(authNotifierProvider.notifier)
          .selectBranch(branch.id);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMsg = e.toString());
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authNotifierProvider.notifier).session;
    final user = session?.user;
    final tenant = session?.tenant;
    final branches = tenant?.branches ?? const <BranchProfile>[];
    final defaultBranchId = user?.branchId;

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Cabang'),
        centerTitle: false,
        actions: [
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Keluar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF991B1B),
              side: const BorderSide(color: Color(0xFFFECACA)),
            ),
          ),
          const SizedBox(width: GoldenitySpacing.md),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              biz.light,
              GoldenityColors.surface2,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GoldenitySpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(tenant, textTheme, biz),
                  const SizedBox(height: GoldenitySpacing.xl),
                  if (_errorMsg != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: GoldenitySpacing.md),
                      padding: const EdgeInsets.symmetric(
                        horizontal: GoldenitySpacing.md,
                        vertical: GoldenitySpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius:
                            BorderRadius.circular(GoldenityRadius.sm),
                        border: Border.all(
                          color: const Color(0xFFFECACA),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: Color(0xFF991B1B),
                          ),
                          const SizedBox(width: GoldenitySpacing.sm),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF991B1B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (branches.isEmpty)
                    _buildEmptyState(textTheme)
                  else
                    ...branches.map(
                      (b) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: GoldenitySpacing.md),
                        child: _BranchCard(
                          branch: b,
                          isDefault: b.id == defaultBranchId,
                          onTap: () => _onPick(b),
                        ),
                      ),
                    ),
                  const SizedBox(height: GoldenitySpacing.md),
                  Center(
                    child: Text(
                      'Login sebagai: ${user?.username ?? '-'} · '
                      '${tenant?.name ?? '-'}',
                      style: textTheme.labelSmall?.copyWith(
                        color: GoldenityColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(tenant, TextTheme textTheme, GoldenityBizColors biz) {
    return Container(
      padding: const EdgeInsets.all(GoldenitySpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        boxShadow: GoldenityElevation.card,
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: biz.light,
              borderRadius: BorderRadius.circular(GoldenityRadius.md),
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 28,
              color: biz.base,
            ),
          ),
          const SizedBox(width: GoldenitySpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant?.name ?? 'Pilih Cabang',
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: GoldenitySpacing.xs),
                Text(
                  'Pilih cabang tempat Anda bekerja saat ini.',
                  style: textTheme.bodySmall?.copyWith(
                    color: GoldenityColors.text2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme textTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GoldenitySpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        boxShadow: GoldenityElevation.card,
        border: Border.all(color: GoldenityColors.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 48,
            color: GoldenityColors.muted,
          ),
          const SizedBox(height: GoldenitySpacing.md),
          Text(
            'Belum ada cabang',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: GoldenitySpacing.xs),
          Text(
            'Tenant ini belum menambahkan data cabang. '
            'Anda dapat melanjutkan tanpa memilih cabang.',
            style: textTheme.bodySmall?.copyWith(
              color: GoldenityColors.text2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final BranchProfile branch;
  final bool isDefault;
  final VoidCallback onTap;

  const _BranchCard({
    required this.branch,
    required this.isDefault,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz =
        theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    final tintedColor = Color.alphaBlend(
      biz.base.withValues(alpha: 0.12),
      Colors.white,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GoldenityRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(GoldenityRadius.lg),
            boxShadow: GoldenityElevation.card,
            border: Border.all(
              color: isDefault ? biz.base : GoldenityColors.border,
              width: isDefault ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(GoldenitySpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: biz.light,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                ),
                child: Icon(
                  Icons.store_rounded,
                  size: 22,
                  color: biz.base,
                ),
              ),
              const SizedBox(width: GoldenitySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            branch.name,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: GoldenitySpacing.sm,
                              vertical: GoldenitySpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: tintedColor,
                              borderRadius:
                                  BorderRadius.circular(GoldenityRadius.md),
                            ),
                            child: Text(
                              'Default',
                              style: textTheme.labelSmall?.copyWith(
                                color: biz.base,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: GoldenitySpacing.xs),
                    Text(
                      'Tap untuk masuk ke cabang ini',
                      style: textTheme.bodySmall?.copyWith(
                        color: GoldenityColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: GoldenitySpacing.sm),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: GoldenityColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
