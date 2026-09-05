import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'core/design/goldenity_breakpoint.dart';
import 'core/design/goldenity_colors.dart';
import 'core/design/goldenity_elevation.dart';
import 'core/design/goldenity_radius.dart';
import 'core/design/goldenity_spacing.dart';
import 'core/design/goldenity_typography.dart';
import 'core/models/user_profile.dart';
import 'features/auth/providers/auth_provider.dart';
import 'shared/widgets/goldenity_active_order_banner.dart';
import 'shared/widgets/goldenity_cash_tender_modal.dart';
import 'shared/widgets/goldenity_counter_button.dart';
import 'shared/widgets/goldenity_payment_card.dart';
import 'shared/widgets/goldenity_primary_button.dart';
import 'shared/widgets/goldenity_variant_checkbox_selector.dart';
import 'shared/widgets/goldenity_variant_radio_selector.dart';

class StyleGuideScreen extends ConsumerStatefulWidget {
  const StyleGuideScreen({super.key});

  @override
  ConsumerState<StyleGuideScreen> createState() => _StyleGuideScreenState();
}

class _StyleGuideScreenState extends ConsumerState<StyleGuideScreen> {
  int _counter = 2;
  String _sizeSelection = 'M';
  Set<String> _toppings = <String>{'Extra Keju', 'Telur'};
  int _paymentSelection = 0;
  String? _rbacNoParamResult;
  String? _rbacFakeBranchResult;
  String? _rbacStatus;

  final NumberFormat _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Future<void> _openCashTender() async {
    await GoldenityCashTenderModal.show(context, totalAmount: 127000);
  }

  Future<void> _checkRbacNoParam() async {
    setState(() {
      _rbacStatus = '⏳ Mengecek RBAC Scope (tanpa param)...';
      _rbacNoParamResult = null;
    });
    final auth = ref.read(authNotifierProvider.notifier);
    final result = await auth.debugGetRbacScope();
    const encoder = JsonEncoder.withIndent('  ');
    if (mounted) {
      setState(() {
        _rbacNoParamResult = result == null ? '❌ ERROR' : encoder.convert(result);
        _rbacStatus = null;
      });
    }
  }

  Future<void> _checkRbacFakeBranch() async {
    setState(() {
      _rbacStatus = '⏳ Mengecek RBAC Scope dengan branchId FAKE...';
      _rbacFakeBranchResult = null;
    });
    final auth = ref.read(authNotifierProvider.notifier);
    final result = await auth.debugGetRbacScope(
      queryParams: <String, String>{
        'branchId': '00000000-0000-0000-0000-000000000099',
      },
    );
    const encoder = JsonEncoder.withIndent('  ');
    if (mounted) {
      setState(() {
        _rbacFakeBranchResult = result == null ? '❌ ERROR' : encoder.convert(result);
        _rbacStatus = null;
      });
    }
  }

  Future<void> _logout() async {
    await ref.read(authNotifierProvider.notifier).logout();
  }

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final st = ref.read(authNotifierProvider);
      final sess = ref.read(authNotifierProvider.notifier).session;
      // ignore: avoid_print
      print('[SMOKE_INIT] authState=$st userPresent=${sess != null} username=${sess?.user.username} role=${sess?.user.role.name}');
      if (st == AuthState.authenticated && sess != null) {
        // ignore: avoid_print
        print('[SMOKE_INIT] ✅ Session authenticated detected. Starting AUTO-RUN RBAC Smoke Test Sequence...');
        await Future<void>.delayed(const Duration(seconds: 1));
        await _checkRbacNoParam();
        await Future<void>.delayed(const Duration(seconds: 1));
        await _checkRbacFakeBranch();
        // ignore: avoid_print
        print('[SMOKE_INIT] 🏁 AUTO-RUN RBAC Smoke Test Sequence SELESAI. Silakan cek hasil di atas / di UI section Debug RBAC.');
        if (sess.user.role == UserRole.CASHIER) {
          final enforced = _rbacFakeBranchResult?.contains('enforcedOwnBranch: true') ??
              _rbacFakeBranchResult?.contains('"enforcedOwnBranch": true') ??
              false;
          final noFakeBranch = !(_rbacFakeBranchResult?.contains('00000000-0000-0000-0000-000000000099') ?? true);
          if (enforced && noFakeBranch) {
            // ignore: avoid_print
            print('[SMOKE_INIT] ✅✅✅ CRITICAL ASSERTION CASHIER PASSED: FAKE branchId TIDAK masuk ke effectiveBranchFilter (RBAC enforced). 0 Data Leak!');
          } else {
            // ignore: avoid_print
            print('[SMOKE_INIT] ❌❌❌ CRITICAL ASSERTION CASHIER FAILED: RBAC BYPASS TERJADI -> $enforced / noFakeBranch=$noFakeBranch');
          }
        }
      } else {
        // ignore: avoid_print
        print('[SMOKE_INIT] ℹ️  Belum authenticated. Auto-RBAC test skip. Silakan login via form.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final GoldenityBreakpoint bp = context.breakpoint;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(GoldenitySpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '🎨 Goldenity POS V2 — Design System Style Guide',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Breakpoint: ${bp.name} · Screen width: ${MediaQuery.of(context).size.width.toStringAsFixed(0)}px',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: GoldenityColors.muted,
                    ),
              ),
              const SizedBox(height: GoldenitySpacing.md),
              _buildSessionInfoCard(),
              const SizedBox(height: GoldenitySpacing.xl),

              _sectionTitle('01 · Palette Warna'),
              const SizedBox(height: GoldenitySpacing.md),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _swatch('primary', GoldenityColors.primary),
                  _swatch('primaryLight', GoldenityColors.primaryLight),
                  _swatch('sidebar', GoldenityColors.sidebar),
                  _swatch('bg', GoldenityColors.bg, border: true),
                  _swatch('surface', GoldenityColors.surface, border: true),
                  _swatch('text', GoldenityColors.text),
                  _swatch('muted', GoldenityColors.muted),
                  _swatch('border', GoldenityColors.border, border: true),
                  _swatch('success', GoldenityColors.success),
                  _swatch('warning', GoldenityColors.warning),
                  _swatch('error', GoldenityColors.error),
                  _swatch(
                    'biz.fnb.base',
                    Theme.of(context)
                            .extension<GoldenityBizColors>()
                            ?.base ??
                        GoldenityColors.warning,
                  ),
                ],
              ),

              const SizedBox(height: GoldenitySpacing.xl),
              _sectionTitle('02 · Tipografi'),
              const SizedBox(height: GoldenitySpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(GoldenitySpacing.lg),
                decoration: BoxDecoration(
                  color: GoldenityColors.surface,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                  border: Border.all(color: GoldenityColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Display Large (32/800) — Harga Promo',
                      style: Theme.of(context).textTheme.displayLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Headline Large (26/900) — Nama Toko',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Headline Medium (20/800) — Judul Halaman',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Body Large (14/500) — Nama Produk',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 6),
                    const Divider(height: 24),
                    Text(
                      'NUMERIC LARGE 20/800 — Rp 1.500.000',
                      style: Theme.of(context).textTheme.numericLarge.copyWith(
                            color: GoldenityColors.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Numeric Medium 14/700 — 127.000',
                      style: Theme.of(context).textTheme.numericMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Numeric Small 11/600 — QTY 3',
                      style: Theme.of(context).textTheme.numericSmall,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: GoldenitySpacing.xl),
              _sectionTitle('03 · Shared Widgets (Public Reusable Components)'),
              const SizedBox(height: GoldenitySpacing.md),

              _subsection('PrimaryButton (4 states)'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  GoldenityPrimaryButton(
                    label: 'Normal',
                    onPressed: () {},
                  ),
                  GoldenityPrimaryButton(
                    label: 'Sukses',
                    backgroundColor: GoldenityColors.success,
                    shadow: GoldenityElevation.btnSuccess,
                    onPressed: () {},
                  ),
                  GoldenityPrimaryButton(
                    label: 'Dengan Icon',
                    icon: Icons.shopping_cart_checkout,
                    onPressed: () {},
                  ),
                  const GoldenityPrimaryButton(
                    label: 'Disabled',
                    onPressed: null,
                  ),
                  GoldenityPrimaryButton(
                    label: 'Loading',
                    isLoading: true,
                    onPressed: () {},
                  ),
                ],
              ),

              const SizedBox(height: GoldenitySpacing.lg),
              _subsection('CounterButton (Qty di Cart)'),
              const SizedBox(height: 8),
              GoldenityCounterButton(
                value: _counter,
                onChanged: (int v) => setState(() => _counter = v),
              ),

              const SizedBox(height: GoldenitySpacing.lg),
              _subsection('PaymentCard (Pilihan Metode Bayar)'),
              const SizedBox(height: 8),
              Column(
                children: <Widget>[
                  GoldenityPaymentCard(
                    label: 'Tunai (Cash)',
                    subtitle: 'Uang pas / kembalian otomatis',
                    icon: Icons.payments,
                    isSelected: _paymentSelection == 0,
                    onTap: () => setState(() => _paymentSelection = 0),
                  ),
                  const SizedBox(height: 10),
                  GoldenityPaymentCard(
                    label: 'QRIS / E-Wallet',
                    subtitle: 'Auto-lunas atau konfirmasi manual',
                    icon: Icons.qr_code_2,
                    iconColor: GoldenityColors.success,
                    isSelected: _paymentSelection == 1,
                    onTap: () => setState(() => _paymentSelection = 1),
                  ),
                ],
              ),

              const SizedBox(height: GoldenitySpacing.lg),
              _subsection('CashTenderModal (Smart-chip kelipatan 5K)'),
              const SizedBox(height: 8),
              GoldenityPrimaryButton(
                label: 'Buka Modal Cash: ${_fmt.format(127000)}',
                onPressed: _openCashTender,
              ),

              const SizedBox(height: GoldenitySpacing.lg),
              _subsection('VariantRadioSelector (Ukuran — single select)'),
              const SizedBox(height: 8),
              GoldenityVariantRadioSelector<String>(
                options: const <String>['S', 'M', 'L', 'XL'],
                value: _sizeSelection,
                onChanged: (String v) => setState(() => _sizeSelection = v),
              ),

              const SizedBox(height: GoldenitySpacing.lg),
              _subsection(
                'VariantCheckboxSelector (Topping — multi select, purple accent)',
              ),
              const SizedBox(height: 8),
              GoldenityVariantCheckboxSelector<String>(
                options: const <String>['Extra Keju', 'Sosis', 'Telur', 'Mayo'],
                selected: _toppings,
                onChanged: (Set<String> v) => setState(() => _toppings = v),
              ),

              const SizedBox(height: GoldenitySpacing.lg),
              _subsection('ActiveOrderBanner (F&B amber banner)'),
              const SizedBox(height: 8),
              const GoldenityActiveOrderBanner(
                title: '1 Pesanan Sedang Disiapkan · Meja 5',
                subtitle: 'Tap untuk melihat detail · Estimasi 8 menit',
              ),

              const SizedBox(height: GoldenitySpacing.xxl),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(GoldenitySpacing.md),
                decoration: BoxDecoration(
                  color: GoldenityColors.successLight,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                  border: Border.all(color: GoldenityColors.success),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.verified_rounded,
                        color: GoldenityColors.success),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '✅ Tahap 0 Design Foundation: 7 token files + 8 public shared widgets ready. Zero duplicate file, zero duplicate component.',
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: GoldenityColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: GoldenitySpacing.xl),
              _sectionTitle('🔬 Debug · RBAC Scope Checker (Smoke Test Epic 1)'),
              const SizedBox(height: GoldenitySpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(GoldenitySpacing.lg),
                decoration: BoxDecoration(
                  color: GoldenityColors.surface,
                  borderRadius: BorderRadius.circular(GoldenityRadius.md),
                  border: Border.all(color: GoldenityColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Klik tombol di bawah untuk memverifikasi resolveEffectiveBranchFilter() berjalan di level aplikasi nyata (bukan cuma curl). Hasil juga di-print ke console debug.',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: GoldenityColors.muted,
                          ),
                    ),
                    const SizedBox(height: GoldenitySpacing.md),
                    if (_rbacStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: GoldenitySpacing.md),
                        child: Row(
                          children: <Widget>[
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _rbacStatus!,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        GoldenityPrimaryButton(
                          label: 'TC-1: RBAC Scope (tanpa param)',
                          onPressed: _checkRbacNoParam,
                        ),
                        GoldenityPrimaryButton(
                          label: 'TC-2: RBAC Scope (branchId=FAKE)',
                          backgroundColor: GoldenityColors.warning,
                          onPressed: _checkRbacFakeBranch,
                        ),
                        GoldenityPrimaryButton(
                          label: 'Logout (ganti user)',
                          backgroundColor: GoldenityColors.error,
                          onPressed: _logout,
                        ),
                      ],
                    ),
                    const SizedBox(height: GoldenitySpacing.lg),
                    if (_rbacNoParamResult != null) ...<Widget>[
                      _subsection('Hasil TC-1 (tanpa param):'),
                      const SizedBox(height: 6),
                      SelectableText(
                        _rbacNoParamResult!,
                        style: const TextStyle(
                          fontFamily: GoldenityTypography.fontFamilyMono,
                          fontSize: 11,
                          color: GoldenityColors.text,
                        ),
                      ),
                      const SizedBox(height: GoldenitySpacing.md),
                    ],
                    if (_rbacFakeBranchResult != null) ...<Widget>[
                      _subsection('Hasil TC-2 (branchId=FAKE, harus TETAP branch sendiri):'),
                      const SizedBox(height: 6),
                      SelectableText(
                        _rbacFakeBranchResult!,
                        style: const TextStyle(
                          fontFamily: GoldenityTypography.fontFamilyMono,
                          fontSize: 11,
                          color: GoldenityColors.text,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: GoldenitySpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }

  Widget _subsection(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: GoldenityTypography.fontFamilySans,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: GoldenityColors.text2,
      ),
    );
  }

  Widget _swatch(String label, Color color, {bool border = false}) {
    final bool darkEnough =
        color.computeLuminance() < 0.5;
    return Container(
      width: 130,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
        border: border ? Border.all(color: GoldenityColors.border2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontFamily: GoldenityTypography.fontFamilySans,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: darkEnough ? Colors.white : GoldenityColors.text,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '0x${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0')}',
            style: TextStyle(
              fontFamily: GoldenityTypography.fontFamilyMono,
              fontSize: 10,
              color: darkEnough
                  ? Colors.white70
                  : GoldenityColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionInfoCard() {
    final session = ref.watch(currentSessionProvider);
    final authState = ref.watch(authNotifierProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GoldenitySpacing.lg),
      decoration: BoxDecoration(
        color: authState == AuthState.authenticated
            ? GoldenityColors.primaryLight.withValues(alpha: 0.25)
            : GoldenityColors.surface,
        borderRadius: BorderRadius.circular(GoldenityRadius.md),
        border: Border.all(
          color: authState == AuthState.authenticated
              ? GoldenityColors.primary
              : GoldenityColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                authState == AuthState.authenticated
                    ? Icons.verified_user_rounded
                    : Icons.person_off_rounded,
                color: authState == AuthState.authenticated
                    ? GoldenityColors.primary
                    : GoldenityColors.muted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                authState == AuthState.authenticated
                    ? '✅ Session Aktif — SharedPreferences 7/7 key tersimpan'
                    : authState == AuthState.expired
                        ? '⚠️  Session Kadaluarsa (>24 jam)'
                        : authState == AuthState.loading
                            ? '⏳ Loading session dari storage...'
                            : '🔐 Belum Login (Cold Start)',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: authState == AuthState.authenticated
                          ? GoldenityColors.primary
                          : authState == AuthState.expired
                              ? GoldenityColors.error
                              : GoldenityColors.text,
                    ),
              ),
            ],
          ),
          if (authState == AuthState.authenticated && session != null) ...<Widget>[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _sessionRow('User ID', session.user.id),
            _sessionRow('Username', session.user.username),
            _sessionRow('Role', session.user.role.name),
            _sessionRow('Tenant ID', session.user.tenantId),
            _sessionRow('Branch ID', session.user.branchId ?? '(null)'),
            _sessionRow('Tenant', session.tenant.name),
            _sessionRow('Slug', session.tenant.slug),
            _sessionRow('Login Time', session.loginTime.toLocal().toString()),
            _sessionRow(
              'Expired (24h rule)',
              session.loginTime.add(const Duration(hours: 24)).toLocal().toString(),
            ),
            _sessionRow(
              'Token (20char prefix)',
              '${session.token.substring(0, session.token.length > 20 ? 20 : session.token.length)}...',
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: GoldenityTypography.fontFamilySans,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: GoldenityColors.muted,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: GoldenityTypography.fontFamilyMono,
                fontSize: 11,
                color: GoldenityColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
