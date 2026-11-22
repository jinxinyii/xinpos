import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product.dart';
import 'product_providers.dart';

final productDetailsProvider = FutureProvider.family<Product?, String>((
  ref,
  productId,
) {
  return ref.watch(productRepositoryProvider).getProductById(productId);
});
