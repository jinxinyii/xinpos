import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../data/repositories/barcode_repository_impl.dart';
import '../../domain/repositories/barcode_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return ProductRepositoryImpl(database);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return CategoryRepositoryImpl(database);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return InventoryRepositoryImpl(database);
});

final barcodeRepositoryProvider = Provider<BarcodeRepository>((ref) {
  final database = ref.watch(databaseProvider);
  return BarcodeRepositoryImpl(database);
});
