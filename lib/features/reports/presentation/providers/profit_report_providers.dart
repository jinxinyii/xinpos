import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../data/repositories/profit_report_repository.dart';
import '../../domain/entities/profit_report.dart';
import '../../domain/entities/sales_report_filter.dart';

final profitReportRepositoryProvider = Provider<ProfitReportRepository>((ref) {
  return ProfitReportRepository(
    ref.watch(databaseProvider),
    businessId: ref.watch(activeBusinessProvider),
  );
});

final profitReportProvider =
    StreamProvider.family<ProfitReport, SalesReportFilter>((ref, filter) {
      final database = ref.watch(databaseProvider);
      final businessId = ref.watch(activeBusinessProvider);
      final repository = ref.watch(profitReportRepositoryProvider);

      return database
          .customSelect(
            'SELECT 1 FROM sales WHERE business_id = ? '
            'UNION ALL SELECT 1 FROM sale_items WHERE business_id = ? '
            'UNION ALL SELECT 1 FROM expenses WHERE business_id = ?',
            variables: [
              Variable.withString(businessId),
              Variable.withString(businessId),
              Variable.withString(businessId),
            ],
            readsFrom: {database.sales, database.saleItems, database.expenses},
          )
          .watch()
          .asyncMap((_) => repository.getReport(filter));
    });
