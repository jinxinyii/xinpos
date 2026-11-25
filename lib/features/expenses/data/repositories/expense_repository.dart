import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/business_expense.dart';

class ExpenseRepository {
  final AppDatabase database;
  final String businessId;

  ExpenseRepository(this.database, {required this.businessId});

  static const _uuid = Uuid();

  Future<void> _ensureBusinessWritable() async {
    final business =
        await (database.select(database.businessDatasets)
              ..where((item) => item.id.equals(businessId))
              ..where((item) => item.isArchived.equals(false)))
            .getSingleOrNull();

    if (business == null) {
      throw StateError('The selected business is unavailable or archived.');
    }
  }

  Future<List<BusinessExpense>> getExpenses() async {
    final query = database.select(database.expenses)
      ..where((expense) => expense.businessId.equals(businessId))
      ..orderBy([
        (expense) => OrderingTerm(
          expression: expense.expenseDate,
          mode: OrderingMode.desc,
        ),
        (expense) => OrderingTerm(
          expression: expense.createdAt,
          mode: OrderingMode.desc,
        ),
      ]);

    final rows = await query.get();

    return rows.map((row) {
      return BusinessExpense(
        id: row.id,
        description: row.description,
        category: row.category,
        amountCentavos: row.amountCentavos,
        paymentMethod: row.paymentMethod,
        expenseDate: DateTime.fromMillisecondsSinceEpoch(row.expenseDate),
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
      );
    }).toList();
  }

  Future<void> saveExpense({
    String? id,
    required String description,
    required String category,
    required int amountCentavos,
    required String? paymentMethod,
    required DateTime expenseDate,
  }) async {
    if (description.trim().isEmpty || category.trim().isEmpty) {
      throw ArgumentError('Description and category are required.');
    }
    if (amountCentavos <= 0) {
      throw ArgumentError('Expense amount must be greater than zero.');
    }

    await database.transaction(() async {
      await _ensureBusinessWritable();

      final now = DateTime.now().millisecondsSinceEpoch;
      final expenseId = id ?? _uuid.v4();

      if (id == null) {
        await database
            .into(database.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: expenseId,
                description: description.trim(),
                category: category,
                amountCentavos: amountCentavos,
                paymentMethod: Value(paymentMethod),
                expenseDate: expenseDate.millisecondsSinceEpoch,
                createdAt: now,
                businessId: Value(businessId),
              ),
            );
        return;
      }

      final updated =
          await (database.update(database.expenses)
                ..where((expense) => expense.id.equals(expenseId))
                ..where((expense) => expense.businessId.equals(businessId)))
              .write(
                ExpensesCompanion(
                  description: Value(description.trim()),
                  category: Value(category),
                  amountCentavos: Value(amountCentavos),
                  paymentMethod: Value(paymentMethod),
                  expenseDate: Value(expenseDate.millisecondsSinceEpoch),
                ),
              );

      if (updated == 0) {
        throw StateError('Expense was not found in the selected business.');
      }
    });
  }

  Future<void> deleteExpense(String id) async {
    await _ensureBusinessWritable();
    final deleted =
        await (database.delete(database.expenses)
              ..where((expense) => expense.id.equals(id))
              ..where((expense) => expense.businessId.equals(businessId)))
            .go();

    if (deleted == 0) {
      throw StateError('Expense was not found in the selected business.');
    }
  }
}
