import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/entities/business_expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(databaseProvider));
});

final expensesProvider = FutureProvider<List<BusinessExpense>>((ref) {
  return ref.watch(expenseRepositoryProvider).getExpenses();
});
