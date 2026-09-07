import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goldenity_pos_native/core/models/product_profile.dart';
import 'package:goldenity_pos_native/features/auth/providers/auth_provider.dart';
import 'package:goldenity_pos_native/features/inventory/providers/product_list_provider.dart';
import 'package:goldenity_pos_native/features/sales/models/cart_item.dart';

enum ManualDiscountType { percentage, nominal }

final cartNotifierProvider = NotifierProvider<CartNotifier, Map<String, CartItem>>(CartNotifier.new);

final manualDiscountTypeProvider = StateProvider<ManualDiscountType>((ref) => ManualDiscountType.percentage);
final manualDiscountValueProvider = StateProvider<num>((ref) => 0);

enum ActiveDiscountSource { none, auto, manualPercentage, manualNominal }

final activeDiscountSourceProvider = Provider<ActiveDiscountSource>((ref) {
  final manualValue = ref.watch(manualDiscountValueProvider);
  if (manualValue > 0) {
    final type = ref.watch(manualDiscountTypeProvider);
    return type == ManualDiscountType.percentage
        ? ActiveDiscountSource.manualPercentage
        : ActiveDiscountSource.manualNominal;
  }
  final autoActive = ref.watch(cartAutoDiscountActiveProvider);
  if (autoActive) return ActiveDiscountSource.auto;
  return ActiveDiscountSource.none;
});

final activeDiscountLabelProvider = Provider<String>((ref) {
  final source = ref.watch(activeDiscountSourceProvider);
  final manualValue = ref.watch(manualDiscountValueProvider);
  switch (source) {
    case ActiveDiscountSource.manualPercentage:
      return 'Diskon Manual ${manualValue.toInt()}%';
    case ActiveDiscountSource.manualNominal:
      return 'Diskon Manual';
    case ActiveDiscountSource.auto:
      return 'Diskon Otomatis (5%)';
    case ActiveDiscountSource.none:
      return 'Diskon';
  }
});

class CartNotifier extends Notifier<Map<String, CartItem>> {
  bool _taxEnabledCached = true;
  int _taxRateCached = 11;
  bool _pricesIncludeTaxCached = false;
  bool _taxConfigLoaded = false;
  // Footer struk dari pengaturan toko (StoreSettingsProfile.receiptFooter) —
  // sebelumnya nilai ini bisa diisi user di halaman Settings tapi TIDAK
  // PERNAH dipakai saat generate struk (payment modal selalu pakai teks
  // default hardcoded). Di-cache sekali di sini bareng config pajak biar
  // hemat 1 API call.
  String? _receiptFooterCached;

  bool get taxEnabled => _taxEnabledCached;
  num get taxRatePercentage => _taxRateCached;
  bool get pricesIncludeTax => _pricesIncludeTaxCached;
  bool get taxConfigReady => _taxConfigLoaded;
  String? get receiptFooter => _receiptFooterCached;

  Future<void> ensureTaxConfigCached({bool force = false}) async {
    if (_taxConfigLoaded && !force) return;
    try {
      final auth = ref.read(authNotifierProvider.notifier);
      final token = auth.session?.token;
      if (token == null) return;
      final settingsApi = ref.read(settingsApiServiceProvider);
      final store = await settingsApi.getStore(authToken: token);
      if (store != null) {
        _taxEnabledCached = store.taxEnabled;
        _taxRateCached = store.taxRatePercentage.toInt();
        _pricesIncludeTaxCached = store.pricesIncludeTax;
        _receiptFooterCached = store.receiptFooter;
      }
      _taxConfigLoaded = true;
    } catch (_) {
      _taxConfigLoaded = false;
    }
  }

  void invalidateTaxCache() {
    _taxConfigLoaded = false;
  }

  @override
  Map<String, CartItem> build() => {};

  void addToCart(ProductProfile product, {int quantity = 1}) {
    final newState = Map<String, CartItem>.from(state);

    // Story 3.1 — deduplikasi item keranjang: match BERURUTAN id → barcode → name.
    // (id sama → pasti gabung; barcode sama walau id beda → gabung; nama sama
    //  untuk item tanpa barcode / item manual → gabung by name.)
    String? matchKey;
    if (newState.containsKey(product.id)) {
      matchKey = product.id;
    } else {
      final pBarcode = product.barcode?.trim() ?? '';
      final pName = product.name.trim().toLowerCase();
      for (final entry in newState.entries) {
        final e = entry.value.product;
        final eBarcode = e.barcode?.trim() ?? '';
        if (pBarcode.isNotEmpty && eBarcode.isNotEmpty && eBarcode == pBarcode) {
          matchKey = entry.key;
          break;
        }
        if (pName.isNotEmpty && e.name.trim().toLowerCase() == pName) {
          matchKey = entry.key;
          break;
        }
      }
    }

    if (matchKey != null) {
      final existing = newState[matchKey]!;
      newState[matchKey] = existing.copyWith(
        quantity: existing.quantity + quantity,
      );
    } else {
      newState[product.id] = CartItem(
        product: product,
        quantity: quantity,
        unitPrice: product.price,
      );
    }
    state = Map.unmodifiable(newState);
  }

  void updateQuantity(String productId, int newQty) {
    if (!state.containsKey(productId)) return;
    final newState = Map<String, CartItem>.from(state);
    if (newQty <= 0) {
      newState.remove(productId);
    } else {
      final existing = newState[productId]!;
      newState[productId] = existing.copyWith(quantity: newQty);
    }
    state = Map.unmodifiable(newState);
  }

  void removeItem(String productId) {
    if (!state.containsKey(productId)) return;
    final newState = Map<String, CartItem>.from(state);
    newState.remove(productId);
    state = Map.unmodifiable(newState);
  }

  void clearCart() {
    state = const {};
    ref.read(manualDiscountTypeProvider.notifier).state = ManualDiscountType.percentage;
    ref.read(manualDiscountValueProvider.notifier).state = 0;
    ref.read(cartServiceChargePercentageProvider.notifier).state = null;
  }
}

final cartTotalItemsProvider = Provider<int>((ref) {
  final cart = ref.watch(cartNotifierProvider);
  return cart.values.fold<int>(0, (sum, item) => sum + item.quantity);
});

final cartSubtotalProvider = Provider<num>((ref) {
  final cart = ref.watch(cartNotifierProvider);
  return cart.values.fold<num>(0, (sum, item) => sum + item.lineSubtotal);
});

final cartAutoDiscountActiveProvider = Provider<bool>((ref) {
  final cart = ref.watch(cartNotifierProvider);
  final subtotal = ref.watch(cartSubtotalProvider);
  return subtotal > 0 && cart.length >= 3;
});

final cartDiscountAmountProvider = Provider<num>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  if (subtotal <= 0) return 0;
  final manualValue = ref.watch(manualDiscountValueProvider);
  if (manualValue > 0) {
    final type = ref.watch(manualDiscountTypeProvider);
    if (type == ManualDiscountType.percentage) {
      final pct = manualValue.clamp(0, 100).toInt();
      return (subtotal * pct / 100).round();
    } else {
      if (manualValue > subtotal) return subtotal.round();
      return manualValue.round();
    }
  }
  final cart = ref.watch(cartNotifierProvider);
  if (cart.length < 3) return 0;
  return (subtotal * 0.05).round();
});

final cartTaxAmountProvider = Provider<num>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountAmountProvider);
  final taxable = subtotal - discount;
  if (taxable <= 0) return 0;
  final notifier = ref.watch(cartNotifierProvider.notifier);
  if (!notifier.taxConfigReady) {
    Future<void>.microtask(() async {
      await notifier.ensureTaxConfigCached();
      Future<void>.delayed(Duration.zero, () => ref.notifyListeners());
    });
  }
  final apply = notifier.taxEnabled;
  final rate = notifier.taxRatePercentage;
  if (!apply || rate <= 0) return 0;
  // Story 3.2 — PPN dinamis:
  //  - inclusive (harga sudah termasuk pajak): reverse-calculate pajak yang
  //    TERKANDUNG di dalam harga → taxable * rate / (100 + rate).
  //  - exclusive: pajak ditambah di atas → taxable * rate / 100.
  if (notifier.pricesIncludeTax) {
    return (taxable * rate / (100 + rate)).round();
  }
  return (taxable * rate / 100).round();
});

final cartServiceChargePercentageProvider = StateProvider<int?>((ref) => null);

final cartServiceChargeAmountProvider = Provider<num>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final pct = ref.watch(cartServiceChargePercentageProvider) ?? 0;
  if (pct <= 0 || subtotal <= 0) return 0;
  return (subtotal * pct ~/ 100);
});

final cartGrandTotalProvider = Provider<num>((ref) {
  final subtotal = ref.watch(cartSubtotalProvider);
  final discount = ref.watch(cartDiscountAmountProvider);
  final tax = ref.watch(cartTaxAmountProvider);
  final sc = ref.watch(cartServiceChargeAmountProvider);
  // Story 3.2 — mode inclusive: pajak SUDAH ada di dalam subtotal, JANGAN ditambah lagi.
  final notifier = ref.watch(cartNotifierProvider.notifier);
  if (notifier.pricesIncludeTax) {
    return subtotal - discount + sc;
  }
  return subtotal - discount + tax + sc;
});

const String kPaymentMethodCash = 'CASH';
const String kPaymentMethodQris = 'QRIS';
const String kPaymentMethodCreditCard = 'CREDIT_CARD';
const List<String> kPaymentMethodValues = [
  kPaymentMethodCash,
  kPaymentMethodQris,
  kPaymentMethodCreditCard,
];

final paymentMethodProvider = StateProvider<String>((ref) => kPaymentMethodCash);

final paymentReferenceNumberProvider = StateProvider<String?>((ref) => null);

final paidAmountProvider = StateProvider<num>((ref) => 0);

final changeAmountProvider = Provider<num>((ref) {
  final paid = ref.watch(paidAmountProvider);
  final grand = ref.watch(cartGrandTotalProvider);
  if (paid < grand) return 0;
  return paid - grand;
});

final isPaidSufficientProvider = Provider<bool>((ref) {
  final paid = ref.watch(paidAmountProvider);
  final grand = ref.watch(cartGrandTotalProvider);
  return paid >= grand;
});

final isPaymentReferenceRequiredProvider = Provider<bool>((ref) {
  final method = ref.watch(paymentMethodProvider);
  return method == kPaymentMethodQris || method == kPaymentMethodCreditCard;
});

final currentPendingOrderIdProvider = StateProvider<String?>((ref) => null);

