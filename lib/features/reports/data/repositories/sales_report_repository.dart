import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/sales_report.dart';
import '../../domain/entities/sales_report_filter.dart';

class SalesReportRepository {
  final AppDatabase database;

  SalesReportRepository(this.database);

  Future<SalesReport> getReport(SalesReportFilter filter) async {
    final variables = [
      Variable.withInt(filter.startTimestamp),
      Variable.withInt(filter.endExclusiveTimestamp),
    ];

    final summaryRow = await database
        .customSelect(
          '''
      SELECT COALESCE(SUM(total_centavos), 0) AS total_revenue,
             COUNT(*) AS transaction_count
      FROM sales
      WHERE status = 'completed' AND sold_at >= ? AND sold_at < ?
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
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND s.sold_at >= ? AND s.sold_at < ?
      ''',
          variables: variables,
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
      WHERE status = 'completed' AND sold_at >= ? AND sold_at < ?
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
      SELECT product_name,
             COALESCE(SUM(quantity), 0) AS quantity_sold,
             COALESCE(SUM(line_total_centavos), 0) AS revenue
      FROM sale_items
      INNER JOIN sales ON sales.id = sale_items.sale_id
      WHERE sales.status = 'completed' AND sales.sold_at >= ? AND sales.sold_at < ?
      GROUP BY product_name
      ORDER BY quantity_sold DESC, revenue DESC
      LIMIT 10
      ''',
          variables: variables,
          readsFrom: {database.sales, database.saleItems},
        )
        .get();

    final paymentRows = await database
        .customSelect(
          '''
      SELECT LOWER(method) AS method,
             COALESCE(SUM(amount_centavos), 0) AS amount,
             COUNT(DISTINCT sale_id) AS transaction_count
      FROM payments
      INNER JOIN sales ON sales.id = payments.sale_id
      WHERE sales.status = 'completed' AND sales.sold_at >= ? AND sales.sold_at < ?
      GROUP BY LOWER(method)
      ORDER BY amount DESC
      ''',
          variables: variables,
          readsFrom: {database.sales, database.payments},
        )
        .get();

    final categoryRows = await database
        .customSelect(
          '''
      SELECT COALESCE(categories.name, 'Uncategorized') AS category_name,
             COALESCE(SUM(sale_items.quantity), 0) AS quantity_sold,
             COALESCE(SUM(sale_items.line_total_centavos), 0) AS revenue
      FROM sale_items
      INNER JOIN sales ON sales.id = sale_items.sale_id
      LEFT JOIN products ON products.id = sale_items.product_id
      LEFT JOIN categories ON categories.id = products.category_id
      WHERE sales.status = 'completed' AND sales.sold_at >= ? AND sales.sold_at < ?
      GROUP BY COALESCE(categories.name, 'Uncategorized')
      ORDER BY revenue DESC
      ''',
          variables: variables,
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
