import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../domain/entities/product.dart';
import 'product_providers.dart';

final productDetailsProvider = StreamProvider.family<Product?, String>((
  ref,
  productId,
) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(productRepositoryProvider);
  return (database.select(database.products)
        ..where((product) => product.id.equals(productId)))
      .watch()
      .asyncMap((_) => repository.getProductById(productId));
});
