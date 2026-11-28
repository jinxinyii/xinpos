import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../domain/services/product_creation_service.dart';

final productCreationServiceProvider = Provider<ProductCreationService>((ref) {
  final database = ref.watch(databaseProvider);
  final businessId = ref.watch(activeBusinessProvider);

  return ProductCreationService(database: database, businessId: businessId);
});
