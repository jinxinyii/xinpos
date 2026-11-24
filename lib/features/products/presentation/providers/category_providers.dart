import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../domain/entities/category.dart';
import 'product_providers.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(categoryRepositoryProvider);
  return database
      .select(database.categories)
      .watch()
      .asyncMap((_) => repository.getCategories());
});
