import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../domain/services/category_management_service.dart';
import 'product_providers.dart';

final categoryManagementServiceProvider = Provider<CategoryManagementService>((
  ref,
) {
  return CategoryManagementService(
    database: ref.watch(databaseProvider),
    repository: ref.watch(categoryRepositoryProvider),
  );
});
