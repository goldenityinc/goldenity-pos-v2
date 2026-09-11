import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/api_constants.dart';
import 'core/config/storage_keys.dart';
import 'core/services/web_order_notification_service.dart';
import 'core/design/goldenity_colors.dart';
import 'core/design/goldenity_radius.dart';
import 'core/design/goldenity_spacing.dart';
import 'core/design/goldenity_theme.dart';
import 'core/services/pin_service.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/branch_selection_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/pin_setup_screen.dart';
import 'features/auth/screens/pin_unlock_screen.dart';
import 'features/inventory/providers/product_list_provider.dart';
import 'features/inventory/repositories/inventory_hive_repository.dart';
import 'features/sales/providers/cart_provider.dart';
import 'features/sales/providers/sales_sync_notifier.dart';
import 'features/sales/repositories/sales_offline_queue.dart';
import 'shared/shell/goldenity_app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await Hive.initFlutter();
  InventoryHiveRepository.registerAdapters();
  final SharedPreferences sp = await SharedPreferences.getInstance();
  // WAJIB sebelum login screen bisa muncul — tanpa ini devBaseUrl jatuh ke
  // default localhost:3001 dan --dart-define=API_BASE_URL tidak pernah kepakai
  // (ApiConstants.initialize() lain di app_shell/FG service baru jalan SETELAH
  // login berhasil — terlambat untuk request login itu sendiri).
  await ApiConstants.initialize(sp);
  final hiveRepo = await InventoryHiveRepository.open();
  final salesOfflineQueue = await SalesOfflineQueue.open();
  // Notifikasi desktop untuk web order baru (jalan walau POS minimize).
  await WebOrderNotificationService.instance.setup();
  const bool kDebugForceClearSessionBeforeAppStart = false;
  // ignore: dead_code
  if (kDebugForceClearSessionBeforeAppStart) {
    await Future.wait(<Future<bool>>[
      sp.remove(StorageKeys.authToken),
      sp.remove(StorageKeys.authTokenType),
      sp.remove(StorageKeys.authExpiresIn),
      sp.remove(StorageKeys.authUser),
      sp.remove(StorageKeys.authTenant),
      sp.remove(StorageKeys.loginTime),
      sp.remove(StorageKeys.lastSavedTenantSlug),
      sp.remove(StorageKeys.authSelectedBranchId),
    ]);
    // ignore: avoid_print
    print('[MAIN_DEBUG_FORCE_CLEAR] ✅ 8/8 StorageKeys dihapus. App start dengan SP KOSONG (cold start debug).');
  }
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sp),
        inventoryHiveRepositoryProvider.overrideWithValue(hiveRepo),
        salesOfflineQueueProvider.overrideWithValue(salesOfflineQueue),
      ],
      child: const GoldenityPOSApp(),
    ),
  );
}

class GoldenityPOSApp extends StatelessWidget {
  const GoldenityPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Goldenity POS V2',
      debugShowCheckedModeBanner: false,
      theme: buildGoldenityTheme(),
      locale: const Locale('id', 'ID'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  Future<void>? _bootstrapFuture;

  Future<void> _ensureBootstrap(WidgetRef ref) async {
    try {
      await ref.read(cartNotifierProvider.notifier).ensureTaxConfigCached();
    } catch (_) {}
    // Hidupkan sinkronisasi penjualan offline (G1) — timer 30 dtk + flush awal.
    try {
      ref.read(salesSyncNotifierProvider.notifier);
    } catch (_) {}
    // Multi-device: daftarkan perangkat ini ke cabang login (idempotent upsert).
    try {
      final session = ref.read(currentSessionProvider);
      final token = session?.token;
      if (token != null) {
        await ref.read(deviceApiServiceProvider).register(
              token: token,
              branchId: session?.selectedBranchId ?? session?.user.branchId,
            );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authNotifierProvider);
    final session = ref.watch(authNotifierProvider.notifier).session;
    switch (state) {
      case AuthState.loading:
        _bootstrapFuture = null;
        return const _SplashLoading();
      case AuthState.authenticated:
        final branches = session?.tenant.branches ?? const [];
        final selectedBranchId = session?.selectedBranchId;
        if (branches.isEmpty) {
          _bootstrapFuture ??= _ensureBootstrap(ref);
          return FutureBuilder<void>(
            future: _bootstrapFuture,
            builder: (ctx, snap) =>
                snap.connectionState == ConnectionState.done
                    ? const GoldenityAppShell()
                    : const _SplashLoading(),
          );
        }
        if (branches.length == 1 && selectedBranchId == null) {
          final onlyBranch = branches.single.id;
          Future<void>.delayed(Duration.zero, () async {
            try {
              await ref
                  .read(authNotifierProvider.notifier)
                  .selectBranch(onlyBranch);
            } catch (_) {}
          });
          _bootstrapFuture = null;
          return const _SplashLoading();
        }
        if (selectedBranchId == null) {
          _bootstrapFuture = null;
          return const BranchSelectionScreen();
        }

        // ── Gerbang PIN Offline (blueprint §2.2) ──
        final notifier = ref.read(authNotifierProvider.notifier);
        final userId = session?.user.id;
        if (userId != null) {
          final pin = ref.read(pinServiceProvider);
          if (pin.isSet(userId)) {
            // Sesi di-restore dari storage (bukan login baru) → minta PIN.
            if (!notifier.freshLogin && !notifier.pinUnlocked) {
              _bootstrapFuture = null;
              return const PinUnlockScreen();
            }
          } else if (notifier.freshLogin &&
              !notifier.pinUnlocked &&
              !pin.wasSkipped(userId)) {
            // Login pertama & belum punya PIN → tawarkan buat (bisa dilewati).
            _bootstrapFuture = null;
            return const PinSetupScreen();
          }
        }

        _bootstrapFuture ??= _ensureBootstrap(ref);
        return FutureBuilder<void>(
          future: _bootstrapFuture,
          builder: (ctx, snap) =>
              snap.connectionState == ConnectionState.done
                  ? const GoldenityAppShell()
                  : const _SplashLoading(),
        );
      case AuthState.unauthenticated:
      case AuthState.expired:
        _bootstrapFuture = null;
        return const LoginScreen();
    }
  }
}

class _SplashLoading extends StatelessWidget {
  const _SplashLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final biz = theme.extension<GoldenityBizColors>() ?? GoldenityBizColors.fnb;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [biz.light, GoldenityColors.surface2],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: biz.light,
                  borderRadius: BorderRadius.circular(GoldenityRadius.xxxl),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 36,
                  color: biz.base,
                ),
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              Text(
                'Goldenity POS',
                style: textTheme.headlineMedium,
              ),
              const SizedBox(height: GoldenitySpacing.md),
              Text(
                'Menyiapkan sesi...',
                style: textTheme.bodyMedium?.copyWith(
                  color: GoldenityColors.text2,
                ),
              ),
              const SizedBox(height: GoldenitySpacing.xl),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
