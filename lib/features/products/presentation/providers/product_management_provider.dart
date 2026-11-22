import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../domain/services/product_management_service.dart';

final productManagementServiceProvider = Provider<ProductManagementService>((
  ref,
) {
  final database = ref.watch(databaseProvider);

  return ProductManagementService(database: database);
});
