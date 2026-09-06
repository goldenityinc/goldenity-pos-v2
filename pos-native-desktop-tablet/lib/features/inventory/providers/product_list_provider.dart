import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/category_profile.dart';
import '../../../core/models/product_profile.dart';
import '../../auth/providers/auth_provider.dart';
import '../repositories/inventory_hive_repository.dart';
import '../services/category_api_service.dart';
import '../services/dashboard_api_service.dart';
import '../services/product_api_service.dart';
import '../services/settings_api_service.dart';
import '../services/shift_api_service.dart';

enum ProductListStatus {
  loading,
  success,
  error,
}

class ProductListState {
  final ProductListStatus status;
  final List<ProductProfile> products;
  final List<CategoryProfile> categories;
  final int total;
  final bool usedIncludeInactiveFallback;
  final bool usedCacheFallback;
  final bool isOfflineMode;
  final String? errorMessage;

  const ProductListState({
    required this.status,
    required this.products,
    required this.categories,
    required this.total,
    required this.usedIncludeInactiveFallback,
    required this.usedCacheFallback,
    required this.isOfflineMode,
    this.errorMessage,
  });

  factory ProductListState.loading() {
    return const ProductListState(
      status: ProductListStatus.loading,
      products: [],
      categories: [],
      total: 0,
      usedIncludeInactiveFallback: false,
      usedCacheFallback: false,
      isOfflineMode: false,
    );
  }

  ProductListState copyWith({
    ProductListStatus? status,
    List<ProductProfile>? products,
    List<CategoryProfile>? categories,
    int? total,
    bool? usedIncludeInactiveFallback,
    bool? usedCacheFallback,
    bool? isOfflineMode,
    String? errorMessage,
  }) {
    return ProductListState(
      status: status ?? this.status,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      total: total ?? this.total,
      usedIncludeInactiveFallback:
          usedIncludeInactiveFallback ?? this.usedIncludeInactiveFallback,
      usedCacheFallback: usedCacheFallback ?? this.usedCacheFallback,
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final inventoryHiveRepositoryProvider = Provider<InventoryHiveRepository>((ref) {
  throw UnimplementedError('inventoryHiveRepositoryProvider must be overridden in main ProviderScope');
});

class ProductListNotifier extends Notifier<ProductListState> {
  @override
  ProductListState build() {
    Future<void>.delayed(Duration.zero, () => load());
    return ProductListState.loading();
  }

  Future<void> loadCategoriesOnly({bool includeInactive = true}) async {
    final auth = ref.read(authNotifierProvider.notifier);
    final session = auth.session;
    if (session == null) return;
    try {
      final cat = ref.read(categoryApiServiceProvider);
      final list = await cat.listCategories(authToken: session.token, includeInactive: includeInactive);
      list.sort((a, b) {
        final sc = a.sortOrder.compareTo(b.sortOrder);
        if (sc != 0) return sc;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      state = state.copyWith(categories: list);
    } catch (_) {}
  }

  Future<void> load() async {
    state = ProductListState.loading();
    final auth = ref.read(authNotifierProvider.notifier);
    final session = auth.session;

    // ============================================================
    // [DEBUG PRINT TIKET 86eyup3pz STEP 3]
    // Capture timing selectedBranchId saat load() di-trigger PERTAMA KALI.
    // POS (halaman default post-login) fire ini LEBIH AWAL dari callback
    // onboarding selectBranch() → dugaan kuat selectedBranchId NULL saat ini.
    // ============================================================
    final debugTime = DateTime.now().toIso8601String();
    final debugSessionBranchId = session?.selectedBranchId;
    final debugProviderHash = identityHashCode(this);
    final debugAuthState = state; // ProductListStatus saat ini
    print('[LOAD_DEBUG_86eyup3pz_ENTRY] '
          'time=$debugTime | '
          'providerHash=$debugProviderHash | '
          'authState=$debugAuthState | '
          'session==null? ${session == null} | '
          'session.selectedBranchId=$debugSessionBranchId | '
          'session.user.username=${session?.user.username ?? '-'} | '
          'session.tenant.slug=${session?.tenant.slug ?? '-'} | '
          'session.tenant.branches_count=${session?.tenant.branches.length ?? -1}');

    if (session == null) {
      state = state.copyWith(
        status: ProductListStatus.error,
        errorMessage: 'Sesi login tidak ditemukan. Silakan login kembali.',
      );
      print('[LOAD_DEBUG_86eyup3pz_EARLY_EXIT] time=$debugTime session==null');
      return;
    }

    final productApi = ref.read(productApiServiceProvider);
    final categoryApi = ref.read(categoryApiServiceProvider);
    final hive = ref.read(inventoryHiveRepositoryProvider);

    CascadeFetchResult? result;
    bool usedTier2 = false;
    bool usedTier3 = false;
    bool offline = false;
    String? lastError;

    result = await productApi.fetchProductsTier1(authToken: session.token);

    if (!result.success || result.products.isEmpty) {
      lastError = result.errorMessage;
      usedTier2 = true;
      result = await productApi.fetchProductsTier2IncludeInactive(
        authToken: session.token,
      );
    }

    if (!result.success || result.products.isEmpty) {
      if (result.errorMessage != null) lastError = result.errorMessage;
      usedTier3 = true;
      if (hive.isCacheValid()) {
        offline = true;
        final cached = hive.getAllProducts();
        if (cached.isNotEmpty) {
          result = CascadeFetchResult.success(
            products: cached,
            total: cached.length,
            tier: CascadeFetchTier.tier3LocalCache,
            cache: true,
          );
        }
      }
    }

    List<CategoryProfile> categories = state.categories;
    try {
      categories = await categoryApi.listCategories(authToken: session.token, includeInactive: true);
      categories.sort((a, b) {
        final sc = a.sortOrder.compareTo(b.sortOrder);
        if (sc != 0) return sc;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    } catch (_) {
      // keep cached categories if any
    }

    if (!result.success || result.products.isEmpty) {
      final debugResultCount = result.products.length;
      final debugSuccess = result.success;
      final debugTier = result.tierReached;
      final debugMsg = result.errorMessage ?? '-';
      print('[LOAD_DEBUG_86eyup3pz_ERROR_EXIT] '
            'time=$debugTime | '
            'providerHash=$debugProviderHash | '
            'result.success=$debugSuccess | '
            'result.tier=$debugTier | '
            'productsCount=$debugResultCount | '
            'errorMessage=$debugMsg | '
            'usedTier2Fallback=$usedTier2 | '
            'usedTier3CacheFallback=$usedTier3 | '
            'offlineMode=$offline | '
            'session.selectedBranchId=$debugSessionBranchId');
      state = state.copyWith(
        status: ProductListStatus.error,
        categories: categories,
        usedIncludeInactiveFallback: usedTier2,
        usedCacheFallback: usedTier3,
        isOfflineMode: offline,
        errorMessage: lastError?.isNotEmpty == true
            ? lastError
            : 'Gagal memuat daftar produk. Silakan cek koneksi atau hubungi admin.',
      );
      return;
    }

    if (!usedTier3) {
      try {
        await hive.putProducts(result.products);
        await hive.markCachedNow();
      } catch (_) {}
    }

    state = state.copyWith(
      status: ProductListStatus.success,
      products: result.products,
      categories: categories,
      total: result.total > 0 ? result.total : result.products.length,
      usedIncludeInactiveFallback: usedTier2,
      usedCacheFallback: usedTier3,
      isOfflineMode: offline,
      errorMessage: null,
    );
    final debugFinalCount = result.products.length;
    print('[LOAD_DEBUG_86eyup3pz_SUCCESS_EXIT] '
          'time=$debugTime | '
          'providerHash=$debugProviderHash | '
          'productsCountFinal=$debugFinalCount | '
          'usedTier2Fallback=$usedTier2 | '
          'usedTier3CacheFallback=$usedTier3 | '
          'offlineMode=$offline | '
          'categoriesCount=${categories.length} | '
          'session.selectedBranchId=$debugSessionBranchId');
  }

  Future<void> addOfflineLocalOnly(ProductProfile product) async {
    final hive = ref.read(inventoryHiveRepositoryProvider);
    await hive.putProduct(product);
    final updated = hive.getAllProducts();
    if (state.status == ProductListStatus.success) {
      state = state.copyWith(
        products: updated,
        total: updated.length,
        isOfflineMode: true,
        usedCacheFallback: true,
      );
    }
  }
}

final categoryApiServiceProvider = Provider<CategoryApiService>((ref) {
  return CategoryApiService();
});

final shiftApiServiceProvider = Provider<ShiftApiService>((ref) {
  return ShiftApiService();
});

final settingsApiServiceProvider = Provider<SettingsApiService>((ref) {
  return SettingsApiService();
});

final dashboardApiServiceProvider = Provider<DashboardApiService>((ref) {
  return DashboardApiService();
});

final productApiServiceProvider = Provider<ProductApiService>((ref) {
  return ProductApiService();
});

final productListNotifierProvider =
    NotifierProvider<ProductListNotifier, ProductListState>(
  ProductListNotifier.new,
);

final groupedProductsProvider =
    Provider<Map<String, List<ProductProfile>>>((ref) {
  final state = ref.watch(productListNotifierProvider);
  final products = ref.watch(filteredProductsProvider);
  final categories = state.categories;
  final grouped = <String, List<ProductProfile>>{};
  final byId = <String, String>{};
  for (final c in categories) {
    byId[c.id] = c.name;
  }
  for (final p in products) {
    final bucket = p.categoryId != null && p.categoryId!.isNotEmpty && byId.containsKey(p.categoryId)
        ? byId[p.categoryId]!
        : (p.category.isNotEmpty ? p.category : 'Tanpa Kategori');
    grouped.putIfAbsent(bucket, () => []);
    grouped[bucket]!.add(p);
  }
  return grouped;
});

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final productCategoryFilterProvider = StateProvider<String?>((ref) => null);

final filteredProductsProvider = Provider<List<ProductProfile>>((ref) {
  final all = ref.watch(productListNotifierProvider).products;
  final q = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  final catId = ref.watch(productCategoryFilterProvider);
  Iterable<ProductProfile> result = all;
  if (q.isNotEmpty) {
    result = result.where((p) => p.name.toLowerCase().contains(q));
  }
  if (catId != null && catId.isNotEmpty) {
    result = result.where((p) => p.categoryId == catId);
  }
  return result.toList();
});
