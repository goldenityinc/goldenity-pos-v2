import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/models/product_profile.dart';
import '../models/pending_sync_item.dart';

class InventoryHiveRepository {
  static const String boxProducts = 'local_products';
  static const String boxCategories = 'local_categories';
  static const String boxPendingSync = 'pending_sync_queue';

  static const Duration cacheMaxAge = Duration(hours: 24);

  static void registerAdapters() {
    Hive.registerAdapter(BranchProfileAdapter());
    Hive.registerAdapter(ProductProfileAdapter());
    Hive.registerAdapter(PendingSyncItemAdapter());
  }

  final Box<ProductProfile> productsBox;
  final Box<List<dynamic>> categoriesBox;
  final Box<PendingSyncItem> pendingSyncBox;

  InventoryHiveRepository._({
    required this.productsBox,
    required this.categoriesBox,
    required this.pendingSyncBox,
  });

  static Future<InventoryHiveRepository> open() async {
    final products = await Hive.openBox<ProductProfile>(boxProducts);
    final categories = await Hive.openBox<List<dynamic>>(boxCategories);
    final pending = await Hive.openBox<PendingSyncItem>(boxPendingSync);
    return InventoryHiveRepository._(
      productsBox: products,
      categoriesBox: categories,
      pendingSyncBox: pending,
    );
  }

  Future<void> putProduct(ProductProfile product) async {
    await productsBox.put(product.id, product);
    await _rebuildCategories();
  }

  Future<void> putProducts(List<ProductProfile> products) async {
    final Map<dynamic, ProductProfile> entries = {};
    for (final p in products) {
      entries[p.id] = p;
    }
    await productsBox.putAll(entries);
    await _rebuildCategories();
  }

  ProductProfile? getProduct(String id) => productsBox.get(id);

  List<ProductProfile> getAllProducts() => productsBox.values.toList();

  Future<void> deleteProduct(String id) async {
    await productsBox.delete(id);
    await _rebuildCategories();
  }

  Future<void> clearAllProducts() async {
    await productsBox.clear();
    await categoriesBox.clear();
  }

  DateTime? getCachedAt() {
    final ts = productsBox.get('__cache_timestamp_meta__') as DateTime?;
    return ts;
  }

  Future<void> markCachedNow() async {
    await productsBox.put('__cache_timestamp_meta__', DateTime.now() as dynamic);
  }

  bool isCacheValid() {
    final ts = getCachedAt();
    if (ts == null) return false;
    return DateTime.now().difference(ts) <= cacheMaxAge;
  }

  Map<String, List<String>> getCategories() {
    final result = <String, List<String>>{};
    for (final key in categoriesBox.keys) {
      final name = key.toString();
      final ids = (categoriesBox.get(key) ?? []).map((e) => e.toString()).toList();
      if (ids.isNotEmpty) result[name] = ids;
    }
    return result;
  }

  Future<void> _rebuildCategories() async {
    final Map<String, List<String>> grouped = {};
    for (final p in productsBox.values) {
      final name = p.category.isEmpty ? 'Lainnya' : p.category;
      grouped.putIfAbsent(name, () => []);
      grouped[name]!.add(p.id);
    }
    await categoriesBox.clear();
    for (final entry in grouped.entries) {
      await categoriesBox.put(entry.key, entry.value);
    }
  }

  List<PendingSyncItem> getAllPendingSync() => pendingSyncBox.values.toList();

  List<PendingSyncItem> getPendingSyncReady() {
    final now = DateTime.now();
    return pendingSyncBox.values.where((item) {
      if (item.failed) return false;
      if (item.nextRetryAt == null) return true;
      return !item.nextRetryAt!.isAfter(now);
    }).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> enqueuePendingSync(PendingSyncItem item) async {
    await pendingSyncBox.put(item.id, item);
  }

  Future<void> updatePendingSync(PendingSyncItem item) async {
    if (pendingSyncBox.containsKey(item.id)) {
      await pendingSyncBox.put(item.id, item);
    }
  }

  Future<void> dequeuePendingSync(String itemId) async {
    await pendingSyncBox.delete(itemId);
  }

  Future<void> clearPendingSync() async {
    await pendingSyncBox.clear();
  }

  int get pendingSyncCount => pendingSyncBox.length;

  Stream<BoxEvent> watchPendingSync() => pendingSyncBox.watch();
}
