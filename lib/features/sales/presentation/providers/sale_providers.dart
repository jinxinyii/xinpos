import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../domain/entities/sale_detail.dart';
import '../../domain/entities/sale_summary.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/services/sale_checkout_service.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  final database = ref.watch(databaseProvider);
  final businessId = ref.watch(activeBusinessProvider);
  return SaleRepositoryImpl(database, businessId: businessId);
});

final saleCheckoutServiceProvider = Provider<SaleCheckoutService>((ref) {
  return SaleCheckoutService(repository: ref.watch(saleRepositoryProvider));
});

final salesHistoryProvider = StreamProvider.family<List<SaleSummary>, String>((
  ref,
  search,
) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return database
      .customSelect(
        'SELECT 1 FROM sales UNION ALL SELECT 1 FROM sale_items '
        'UNION ALL SELECT 1 FROM payments UNION ALL SELECT 1 FROM queue_entries',
        readsFrom: {
          database.sales,
          database.saleItems,
          database.payments,
          database.queueEntries,
        },
      )
      .watch()
      .asyncMap((_) => repository.getSales(search: search));
});

final saleDetailsProvider = StreamProvider.family<SaleDetail?, String>((
  ref,
  saleId,
) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return database
      .customSelect(
        'SELECT 1 FROM sales WHERE id = ? UNION ALL '
        'SELECT 1 FROM sale_items WHERE sale_id = ? UNION ALL '
        'SELECT 1 FROM payments WHERE sale_id = ? UNION ALL '
        'SELECT 1 FROM queue_entries WHERE sale_id = ?',
        variables: [
          Variable.withString(saleId),
          Variable.withString(saleId),
          Variable.withString(saleId),
          Variable.withString(saleId),
        ],
        readsFrom: {
          database.sales,
          database.saleItems,
          database.payments,
          database.queueEntries,
        },
      )
      .watch()
      .asyncMap((_) => repository.getSaleDetails(saleId));
});
