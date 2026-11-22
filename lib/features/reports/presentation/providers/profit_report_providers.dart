import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/profit_report_repository.dart';
import '../../domain/entities/profit_report.dart';
import '../../domain/entities/sales_report_filter.dart';

final profitReportRepositoryProvider = Provider<ProfitReportRepository>((ref) {
  return ProfitReportRepository(ref.watch(databaseProvider));
});

final profitReportProvider =
    FutureProvider.family<ProfitReport, SalesReportFilter>((ref, filter) {
      return ref.watch(profitReportRepositoryProvider).getReport(filter);
    });
