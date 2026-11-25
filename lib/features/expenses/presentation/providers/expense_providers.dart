import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../../businesses/presentation/providers/active_business_provider.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/entities/business_expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(
    ref.watch(databaseProvider),
    businessId: ref.watch(activeBusinessProvider),
  );
});

final expensesProvider = StreamProvider<List<BusinessExpense>>((ref) {
  final database = ref.watch(databaseProvider);
  final businessId = ref.watch(activeBusinessProvider);
  final repository = ref.watch(expenseRepositoryProvider);

  return (database.select(database.expenses)
        ..where((expense) => expense.businessId.equals(businessId)))
      .watch()
      .asyncMap((_) => repository.getExpenses());
});
