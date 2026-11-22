import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import 'product_providers.dart';

typedef ProductFilter = ({String search, String? categoryId});

final productsListProvider =
    FutureProvider.family<List<Product>, ProductFilter>((ref, filter) {
      return ref
          .watch(productRepositoryProvider)
          .getProducts(search: filter.search, categoryId: filter.categoryId);
    });
