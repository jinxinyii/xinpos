import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
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
  final businessId = ref.watch(activeBusinessProvider);
  return ProductRepositoryImpl(database, businessId);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final businessId = ref.watch(activeBusinessProvider);
  return CategoryRepositoryImpl(database, businessId);
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final businessId = ref.watch(activeBusinessProvider);
  return InventoryRepositoryImpl(database, businessId);
});

final barcodeRepositoryProvider = Provider<BarcodeRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final businessId = ref.watch(activeBusinessProvider);
  return BarcodeRepositoryImpl(database, businessId);
});
