import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../domain/entities/category.dart';
import 'product_providers.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(categoryRepositoryProvider);
  final businessId = ref.watch(activeBusinessProvider);
  final query = database.select(database.categories)
    ..where((category) => category.businessId.equals(businessId));
  return query.watch().asyncMap((_) => repository.getCategories());
});
