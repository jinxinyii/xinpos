import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../domain/entities/product.dart';
import 'product_providers.dart';

typedef ProductFilter = ({String search, String? categoryId});

final productsListProvider =
    StreamProvider.family<List<Product>, ProductFilter>((ref, filter) {
      final database = ref.watch(databaseProvider);
      final repository = ref.watch(productRepositoryProvider);
      return database
          .customSelect(
            'SELECT 1 FROM products',
            readsFrom: {database.products},
          )
          .watch()
          .asyncMap(
            (_) => repository.getProducts(
              search: filter.search,
              categoryId: filter.categoryId,
            ),
          );
    });
