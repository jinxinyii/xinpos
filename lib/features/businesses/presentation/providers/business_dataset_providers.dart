import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/business_dataset_repository.dart';
import '../../domain/entities/business_dataset_summary.dart';

final businessDatasetRepositoryProvider = Provider<BusinessDatasetRepository>((
  ref,
) {
  return BusinessDatasetRepository(ref.watch(databaseProvider));
});

final businessDatasetsProvider = StreamProvider<List<BusinessDatasetSummary>>((
  ref,
) {
  return ref.watch(businessDatasetRepositoryProvider).watchAll();
});
