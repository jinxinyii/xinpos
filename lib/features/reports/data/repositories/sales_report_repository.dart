import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/entities/sales_report_filter.dart';

class SalesReportRepository {
  final AppDatabase database;
  final String businessId;

  SalesReportRepository(this.database, {required this.businessId});

  Future<SalesReport> getReport(SalesReportFilter filter) async {
    final variables = [
      Variable.withString(businessId),
      Variable.withInt(filter.startTimestamp),
      Variable.withInt(filter.endExclusiveTimestamp),
    ];

    final summaryRow = await database
        .customSelect(
          '''
      SELECT COALESCE(SUM(total_centavos), 0) AS total_revenue,
             COUNT(*) AS transaction_count
      FROM sales
      WHERE business_id = ? AND status = 'completed'
        AND sold_at >= ? AND sold_at < ?
      ''',
          variables: variables,
          readsFrom: {database.sales},
        )
        .getSingle();

    final itemRow = await database
        .customSelect(
          '''
      SELECT COALESCE(SUM(si.quantity), 0) AS total_items
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id AND s.business_id = si.business_id
      WHERE s.business_id = ? AND si.business_id = ?
        AND s.status = 'completed' AND s.sold_at >= ? AND s.sold_at < ?
      ''',
          variables: [
            Variable.withString(businessId),
            Variable.withString(businessId),
            Variable.withInt(filter.startTimestamp),
            Variable.withInt(filter.endExclusiveTimestamp),
          ],
          readsFrom: {database.sales, database.saleItems},
        )
        .getSingle();

    final dailyRows = await database
        .customSelect(
          '''
      SELECT date(sold_at / 1000, 'unixepoch', 'localtime') AS sale_date,
             COALESCE(SUM(total_centavos), 0) AS revenue,
             COUNT(*) AS transaction_count
      FROM sales
      WHERE business_id = ? AND status = 'completed'
        AND sold_at >= ? AND sold_at < ?
      GROUP BY date(sold_at / 1000, 'unixepoch', 'localtime')
      ORDER BY sale_date ASC
      ''',
          variables: variables,
          readsFrom: {database.sales},
        )
        .get();

    final productRows = await database
        .customSelect(
          '''
      SELECT si.product_name,
             COALESCE(SUM(si.quantity), 0) AS quantity_sold,
             COALESCE(SUM(si.line_total_centavos), 0) AS revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id AND s.business_id = si.business_id
      WHERE s.business_id = ? AND si.business_id = ?
        AND s.status = 'completed' AND s.sold_at >= ? AND s.sold_at < ?
      GROUP BY si.product_name
      ORDER BY quantity_sold DESC, revenue DESC
      LIMIT 10
      ''',
          variables: [
            Variable.withString(businessId),
            Variable.withString(businessId),
            Variable.withInt(filter.startTimestamp),
            Variable.withInt(filter.endExclusiveTimestamp),
          ],
          readsFrom: {database.sales, database.saleItems},
        )
        .get();

    final paymentRows = await database
        .customSelect(
          '''
      SELECT LOWER(p.method) AS method,
             COALESCE(SUM(p.amount_centavos), 0) AS amount,
             COUNT(DISTINCT p.sale_id) AS transaction_count
      FROM payments p
      INNER JOIN sales s ON s.id = p.sale_id AND s.business_id = p.business_id
      WHERE s.business_id = ? AND p.business_id = ?
        AND s.status = 'completed' AND s.sold_at >= ? AND s.sold_at < ?
      GROUP BY LOWER(p.method)
      ORDER BY amount DESC
      ''',
          variables: [
            Variable.withString(businessId),
            Variable.withString(businessId),
            Variable.withInt(filter.startTimestamp),
            Variable.withInt(filter.endExclusiveTimestamp),
          ],
          readsFrom: {database.sales, database.payments},
        )
        .get();

    final categoryRows = await database
        .customSelect(
          '''
      SELECT COALESCE(c.name, 'Uncategorized') AS category_name,
             COALESCE(SUM(si.quantity), 0) AS quantity_sold,
             COALESCE(SUM(si.line_total_centavos), 0) AS revenue
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id AND s.business_id = si.business_id
      LEFT JOIN products p ON p.id = si.product_id AND p.business_id = si.business_id
      LEFT JOIN categories c ON c.id = p.category_id AND c.business_id = p.business_id
      WHERE s.business_id = ? AND si.business_id = ?
        AND s.status = 'completed' AND s.sold_at >= ? AND s.sold_at < ?
      GROUP BY COALESCE(c.name, 'Uncategorized')
      ORDER BY revenue DESC
      ''',
          variables: [
            Variable.withString(businessId),
            Variable.withString(businessId),
            Variable.withInt(filter.startTimestamp),
            Variable.withInt(filter.endExclusiveTimestamp),
          ],
          readsFrom: {
            database.sales,
            database.saleItems,
            database.products,
            database.categories,
          },
        )
        .get();

    final revenue = summaryRow.read<int>('total_revenue');
    final transactionCount = summaryRow.read<int>('transaction_count');

    return SalesReport(
      totalRevenueCentavos: revenue,
      transactionCount: transactionCount,
      totalItemsSold: itemRow.read<int>('total_items'),
      averageTransactionCentavos: transactionCount == 0
          ? 0
          : (revenue / transactionCount).round(),
      dailySales: dailyRows.map((row) {
        return DailySalesPoint(
          date: DateTime.parse(row.read<String>('sale_date')),
          revenueCentavos: row.read<int>('revenue'),
          transactionCount: row.read<int>('transaction_count'),
        );
      }).toList(),
      topProducts: productRows.map((row) {
        return TopProductSales(
          productName: row.read<String>('product_name'),
          quantitySold: row.read<int>('quantity_sold'),
          revenueCentavos: row.read<int>('revenue'),
        );
      }).toList(),
      paymentMethods: paymentRows.map((row) {
        return PaymentMethodSales(
          method: row.read<String>('method'),
          amountCentavos: row.read<int>('amount'),
          transactionCount: row.read<int>('transaction_count'),
        );
      }).toList(),
      categorySales: categoryRows.map((row) {
        return CategorySales(
          categoryName: row.read<String>('category_name'),
          quantitySold: row.read<int>('quantity_sold'),
          revenueCentavos: row.read<int>('revenue'),
        );
      }).toList(),
    );
  }
}
