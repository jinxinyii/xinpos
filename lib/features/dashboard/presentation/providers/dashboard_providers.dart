import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../domain/entities/dashboard_data.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(databaseProvider));
});

final dashboardDataProvider = FutureProvider<DashboardData>((ref) {
  return ref.watch(dashboardRepositoryProvider).getTodayOverview();
});
