import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/sales_report_repository.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/entities/sales_report_filter.dart';

final salesReportRepositoryProvider = Provider<SalesReportRepository>((ref) {
  return SalesReportRepository(ref.watch(databaseProvider));
});

final salesReportProvider =
    StreamProvider.family<SalesReport, SalesReportFilter>((ref, filter) {
      final database = ref.watch(databaseProvider);
      final repository = ref.watch(salesReportRepositoryProvider);
      return database
          .customSelect(
            'SELECT 1 FROM sales UNION ALL SELECT 1 FROM sale_items '
            'UNION ALL SELECT 1 FROM payments UNION ALL SELECT 1 FROM products '
            'UNION ALL SELECT 1 FROM categories',
            readsFrom: {
              database.sales,
              database.saleItems,
              database.payments,
              database.products,
              database.categories,
            },
          )
          .watch()
          .asyncMap((_) => repository.getReport(filter));
    });
