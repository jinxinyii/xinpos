import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../data/repositories/sales_report_repository.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/entities/sales_report_filter.dart';

final salesReportRepositoryProvider = Provider<SalesReportRepository>((ref) {
  return SalesReportRepository(
    ref.watch(databaseProvider),
    businessId: ref.watch(activeBusinessProvider),
  );
});

final salesReportProvider =
    StreamProvider.family<SalesReport, SalesReportFilter>((ref, filter) {
      final database = ref.watch(databaseProvider);
      final businessId = ref.watch(activeBusinessProvider);
      final repository = ref.watch(salesReportRepositoryProvider);

      return database
          .customSelect(
            '''
        SELECT 1 FROM sales WHERE business_id = ?
        UNION ALL SELECT 1 FROM sale_items WHERE business_id = ?
        UNION ALL SELECT 1 FROM payments WHERE business_id = ?
        UNION ALL SELECT 1 FROM products WHERE business_id = ?
        UNION ALL SELECT 1 FROM categories WHERE business_id = ?
        ''',
            variables: List.generate(5, (_) => Variable.withString(businessId)),
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
