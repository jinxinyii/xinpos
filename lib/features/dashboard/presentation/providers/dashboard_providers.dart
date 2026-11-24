import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../domain/entities/dashboard_data.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(databaseProvider));
});

final dashboardDataProvider = StreamProvider<DashboardData>((ref) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(dashboardRepositoryProvider);
  return database
      .customSelect(
        'SELECT 1 FROM sales UNION ALL SELECT 1 FROM payments',
        readsFrom: {database.sales, database.payments},
      )
      .watch()
      .asyncMap((_) => repository.getTodayOverview());
});
