import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/storage_keys.dart';
import '../../../core/design/goldenity_colors.dart';
import '../../../core/design/goldenity_elevation.dart';
import '../../../core/design/goldenity_radius.dart';
import '../../../core/design/goldenity_spacing.dart';
import '../../../shared/widgets/goldenity_primary_button.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const int _kDebugAutoLoginMode = 0;

  final _formKey = GlobalKey<FormState>();
  final _tenantSlugController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _loadLastTenantSlug();
    if (_kDebugAutoLoginMode > 0) {
      Future<void>(() async {
        if (!mounted) return;
        final String tenant;
        final String user;
        final String pass;
        switch (_kDebugAutoLoginMode) {
          case 1:
            tenant = 'demo-fnb'; user = 'admin'; pass = 'admin123'; break;
          case 2:
            tenant = 'demo-fnb'; user = 'kasir'; pass = 'kasir123'; break;
          default:
            return;
        }
        // ignore: avoid_print
        print('[DEBUG_AUTO_LOGIN] MODE=$_kDebugAutoLoginMode. STEP-1: Force logout dulu (hapus session sisa admin)...');
        await ref.read(authNotifierProvider.notifier).logout();
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        // ignore: avoid_print
        print('[DEBUG_AUTO_LOGIN] MODE=$_kDebugAutoLoginMode. STEP-2: Auto-submit login($tenant/$user/*******)');
        _tenantSlugController.text = tenant;
        _usernameController.text = user;
        _passwordController.text = pass;
        if (mounted) {
          await _submit();
          // ignore: avoid_print
          print('[DEBUG_AUTO_LOGIN] MODE=$_kDebugAutoLoginMode. DONE.');
        }
      });
    }
  }

  @override
  void dispose() {
    _tenantSlugController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadLastTenantSlug() async {
    try {
      final sp = ref.read(sharedPreferencesProvider);
      final last = sp.getString(StorageKeys.lastSavedTenantSlug);
      if (last != null && last.isNotEmpty && mounted) {
        setState(() {
          _tenantSlugController.text = last;
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk) return;
    setState(() => _submitError = null);
    final notifier = ref.read(authNotifierProvider.notifier);
    final (ok, err) = await notifier.login(
      tenantSlug: _tenantSlugController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (!ok && mounted) {
      setState(() => _submitError = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final expiredMessage = ref.watch(authErrorMessageProvider);
    final isLoading = authState == AuthState.loading;

    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;

    return Scaffold(
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(GoldenitySpacing.xxl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(GoldenityRadius.lg),
                    boxShadow: GoldenityElevation.cardHover,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(biz, textTheme),
                      const SizedBox(height: GoldenitySpacing.xl),
                      if (expiredMessage != null)
                        _buildInfoBanner(
                          message: expiredMessage,
                          isError: false,
                          icon: Icons.timer_outlined,
                          backgroundColor: const Color(0xFFFFFBEB),
                          borderColor: const Color(0xFFFDE68A),
                          textColor: const Color(0xFF92400E),
                          textTheme: textTheme,
                        ),
                      if (_submitError != null) ...[
                        _buildInfoBanner(
                          message: _submitError!,
                          isError: true,
                          icon: Icons.error_outline,
                          backgroundColor: const Color(0xFFFEF2F2),
                          borderColor: const Color(0xFFFECACA),
                          textColor: const Color(0xFF991B1B),
                          textTheme: textTheme,
                        ),
                        const SizedBox(height: GoldenitySpacing.lg),
                      ],
                      _buildTenantField(isLoading, biz),
                      const SizedBox(height: GoldenitySpacing.lg),
                      _buildUsernameField(isLoading),
                      const SizedBox(height: GoldenitySpacing.lg),
                      _buildPasswordField(isLoading),
                      const SizedBox(height: GoldenitySpacing.xxl),
                      GoldenityPrimaryButton(
                        label: 'Masuk',
                        icon: Icons.login,
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _submit,
                      ),
                      const SizedBox(height: GoldenitySpacing.lg),
                      _buildFooterHint(textTheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(GoldenityBizColors biz, TextTheme textTheme) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: biz.light,
            borderRadius: BorderRadius.circular(GoldenityRadius.md),
          ),
          child: Icon(
            Icons.storefront_rounded,
            size: 32,
            color: biz.base,
          ),
        ),
        const SizedBox(height: GoldenitySpacing.lg),
        Text(
          'Goldenity POS',
          style: textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: GoldenitySpacing.xs),
        Text(
          'Masukkan kredensial untuk memulai transaksi',
          style: textTheme.bodySmall
              ?.copyWith(color: GoldenityColors.text2),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildInfoBanner({
    required String message,
    required bool isError,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
    required TextTheme textTheme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: GoldenitySpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: GoldenitySpacing.md,
        vertical: GoldenitySpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(GoldenityRadius.sm),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: GoldenitySpacing.sm),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantField(bool isLoading, GoldenityBizColors biz) {
    return TextFormField(
      controller: _tenantSlugController,
      enabled: !isLoading,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: 'Tenant Slug',
        hintText: 'Contoh: demo-fnb',
        prefixIcon: Icon(Icons.apartment_outlined, color: biz.base),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Tenant slug wajib diisi';
        }
        return null;
      },
    );
  }

  Widget _buildUsernameField(bool isLoading) {
    return TextFormField(
      controller: _usernameController,
      enabled: !isLoading,
      textInputAction: TextInputAction.next,
      autocorrect: false,
      decoration: const InputDecoration(
        labelText: 'Username',
        hintText: 'Contoh: admin',
        prefixIcon: Icon(Icons.person_outline),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Username wajib diisi';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(bool isLoading) {
    return TextFormField(
      controller: _passwordController,
      enabled: !isLoading,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.send,
      onFieldSubmitted: (_) => isLoading ? null : _submit(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
          onPressed: isLoading
              ? null
              : () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Password wajib diisi';
        }
        return null;
      },
    );
  }

  Widget _buildFooterHint(TextTheme textTheme) {
    return Text(
      'Lupa kredensial? Hubungi admin tenant Anda.',
      style: textTheme.labelSmall
          ?.copyWith(color: GoldenityColors.muted),
      textAlign: TextAlign.center,
    );
  }
}
