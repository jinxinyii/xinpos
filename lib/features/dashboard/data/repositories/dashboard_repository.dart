import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/dashboard_data.dart';

class DashboardRepository {
  final AppDatabase database;

  DashboardRepository(this.database);

  Future<DashboardData> getTodayOverview() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).millisecondsSinceEpoch;

    final summary = await database
        .customSelect(
          '''
      SELECT
        COALESCE(SUM(s.total_centavos), 0) AS total_sales,
        COUNT(DISTINCT s.id) AS transaction_count,
        COALESCE(SUM(CASE WHEN LOWER(p.method) = 'cash' THEN p.amount_centavos ELSE 0 END), 0) AS cash_sales,
        COALESCE(SUM(CASE WHEN LOWER(p.method) = 'gcash' THEN p.amount_centavos ELSE 0 END), 0) AS gcash_sales
      FROM sales s
      LEFT JOIN payments p ON p.sale_id = s.id
      WHERE s.status = 'completed'
        AND s.sold_at >= ?
        AND s.sold_at < ?
      ''',
          variables: [Variable.withInt(start), Variable.withInt(end)],
          readsFrom: {database.sales, database.payments},
        )
        .getSingle();

    final recentRows = await database
        .customSelect(
          '''
      SELECT s.id, s.receipt_number, s.total_centavos, s.sold_at, s.status,
             COALESCE(
               (SELECT p.method FROM payments p
                WHERE p.sale_id = s.id
                ORDER BY p.paid_at DESC LIMIT 1),
               ''
             ) AS payment_method
      FROM sales s
      WHERE s.sold_at >= ? AND s.sold_at < ?
      ORDER BY s.sold_at DESC
      LIMIT 5
      ''',
          variables: [Variable.withInt(start), Variable.withInt(end)],
          readsFrom: {database.sales, database.payments},
        )
        .get();

    return DashboardData(
      totalSalesCentavos: summary.read<int>('total_sales'),
      transactionCount: summary.read<int>('transaction_count'),
      cashSalesCentavos: summary.read<int>('cash_sales'),
      gcashSalesCentavos: summary.read<int>('gcash_sales'),
      recentSales: recentRows.map((row) {
        return DashboardRecentSale(
          id: row.read<String>('id'),
          receiptNumber: row.read<String>('receipt_number'),
          totalCentavos: row.read<int>('total_centavos'),
          soldAt: DateTime.fromMillisecondsSinceEpoch(row.read<int>('sold_at')),
          paymentMethod: row.read<String>('payment_method'),
          status: row.read<String>('status'),
        );
      }).toList(),
    );
  }
}
