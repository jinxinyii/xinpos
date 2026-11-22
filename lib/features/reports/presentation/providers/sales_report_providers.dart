import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/sales_report_repository.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/entities/sales_report_filter.dart';

final salesReportRepositoryProvider = Provider<SalesReportRepository>((ref) {
  return SalesReportRepository(ref.watch(databaseProvider));
});

final salesReportProvider =
    FutureProvider.family<SalesReport, SalesReportFilter>((ref, filter) {
      return ref.watch(salesReportRepositoryProvider).getReport(filter);
    });
