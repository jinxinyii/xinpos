import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../domain/entities/dashboard_data.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(
    ref.watch(databaseProvider),
    businessId: ref.watch(activeBusinessProvider),
  );
});

final dashboardDataProvider = StreamProvider<DashboardData>((ref) {
  final database = ref.watch(databaseProvider);
  final businessId = ref.watch(activeBusinessProvider);
  final repository = ref.watch(dashboardRepositoryProvider);

  return database
      .customSelect(
        '''
    SELECT 1 FROM sales WHERE business_id = ?
    UNION ALL SELECT 1 FROM payments WHERE business_id = ?
    ''',
        variables: [
          Variable.withString(businessId),
          Variable.withString(businessId),
        ],
        readsFrom: {database.sales, database.payments},
      )
      .watch()
      .asyncMap((_) => repository.getTodayOverview());
});
