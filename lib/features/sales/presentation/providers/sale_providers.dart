import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/sale_repository_impl.dart';
import '../../domain/entities/sale_detail.dart';
import '../../domain/entities/sale_summary.dart';
import '../../domain/repositories/sale_repository.dart';
import '../../domain/services/sale_checkout_service.dart';

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepositoryImpl(ref.watch(databaseProvider));
});

final saleCheckoutServiceProvider = Provider<SaleCheckoutService>((ref) {
  return SaleCheckoutService(repository: ref.watch(saleRepositoryProvider));
});

final salesHistoryProvider = FutureProvider.family<List<SaleSummary>, String>((
  ref,
  search,
) {
  return ref.watch(saleRepositoryProvider).getSales(search: search);
});

final saleDetailsProvider = FutureProvider.family<SaleDetail?, String>((
  ref,
  saleId,
) {
  return ref.watch(saleRepositoryProvider).getSaleDetails(saleId);
});
