import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/profit_report.dart';
import '../../domain/entities/sales_report_filter.dart';

class ProfitReportRepository {
  final AppDatabase database;

  ProfitReportRepository(this.database);

  Future<ProfitReport> getReport(SalesReportFilter filter) async {
    final variables = [
      Variable.withInt(filter.startTimestamp),
      Variable.withInt(filter.endExclusiveTimestamp),
    ];

    final salesRow = await database
        .customSelect(
          '''
      SELECT COALESCE(SUM(total_centavos), 0) AS revenue,
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
      SELECT COALESCE(SUM(si.quantity), 0) AS items_sold,
             COALESCE(SUM(si.quantity * si.unit_cost_centavos), 0) AS cogs
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND s.sold_at >= ? AND s.sold_at < ?
      ''',
          variables: variables,
          readsFrom: {database.sales, database.saleItems},
        )
        .getSingle();

    final expenseRow = await database
        .customSelect(
          '''
      SELECT COALESCE(SUM(amount_centavos), 0) AS expenses
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      ''',
          variables: variables,
          readsFrom: {database.expenses},
        )
        .getSingle();

    final dailyRows = await database
        .customSelect(
          '''
      WITH daily_sales AS (
        SELECT
          date(sold_at / 1000, 'unixepoch', 'localtime') AS report_date,
          COALESCE(SUM(total_centavos), 0) AS revenue,
          COALESCE(SUM((
            SELECT SUM(si.quantity * si.unit_cost_centavos)
            FROM sale_items si
            WHERE si.sale_id = sales.id
          )), 0) AS cogs
        FROM sales
        WHERE status = 'completed' AND sold_at >= ? AND sold_at < ?
        GROUP BY date(sold_at / 1000, 'unixepoch', 'localtime')
      ),
      daily_expenses AS (
        SELECT
          date(expense_date / 1000, 'unixepoch', 'localtime') AS report_date,
          COALESCE(SUM(amount_centavos), 0) AS expenses
        FROM expenses
        WHERE expense_date >= ? AND expense_date < ?
        GROUP BY date(expense_date / 1000, 'unixepoch', 'localtime')
      ),
      report_dates AS (
        SELECT report_date FROM daily_sales
        UNION
        SELECT report_date FROM daily_expenses
      )
      SELECT report_dates.report_date,
             COALESCE(daily_sales.revenue, 0) AS revenue,
             COALESCE(daily_sales.cogs, 0) AS cogs,
             COALESCE(daily_expenses.expenses, 0) AS expenses
      FROM report_dates
      LEFT JOIN daily_sales ON daily_sales.report_date = report_dates.report_date
      LEFT JOIN daily_expenses ON daily_expenses.report_date = report_dates.report_date
      ORDER BY report_dates.report_date ASC
      ''',
          variables: [...variables, ...variables],
          readsFrom: {database.sales, database.saleItems, database.expenses},
        )
        .get();

    final categoryRows = await database
        .customSelect(
          '''
      SELECT category, COALESCE(SUM(amount_centavos), 0) AS amount
      FROM expenses
      WHERE expense_date >= ? AND expense_date < ?
      GROUP BY category
      ORDER BY amount DESC
      ''',
          variables: variables,
          readsFrom: {database.expenses},
        )
        .get();

    final productRows = await database
        .customSelect(
          '''
      SELECT si.product_name,
             COALESCE(SUM(si.quantity), 0) AS quantity_sold,
             COALESCE(SUM(si.line_total_centavos), 0) AS revenue,
             COALESCE(SUM(si.quantity * si.unit_cost_centavos), 0) AS cogs
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.status = 'completed' AND s.sold_at >= ? AND s.sold_at < ?
      GROUP BY si.product_name
      ORDER BY (SUM(si.line_total_centavos) - SUM(si.quantity * si.unit_cost_centavos)) DESC, quantity_sold DESC
      LIMIT 10
      ''',
          variables: variables,
          readsFrom: {database.sales, database.saleItems},
        )
        .get();

    final revenue = salesRow.read<int>('revenue');
    final cogs = itemRow.read<int>('cogs');
    final grossProfit = revenue - cogs;
    final expenses = expenseRow.read<int>('expenses');
    final netProfit = grossProfit - expenses;

    return ProfitReport(
      revenueCentavos: revenue,
      costOfGoodsSoldCentavos: cogs,
      grossProfitCentavos: grossProfit,
      operatingExpensesCentavos: expenses,
      netProfitCentavos: netProfit,
      transactionCount: salesRow.read<int>('transaction_count'),
      itemsSold: itemRow.read<int>('items_sold'),
      profitMarginPercent: revenue == 0 ? 0 : (netProfit / revenue) * 100,
      dailyProfit: dailyRows.map((row) {
        final dayRevenue = row.read<int>('revenue');
        final dayCogs = row.read<int>('cogs');
        final dayExpenses = row.read<int>('expenses');
        return DailyProfitPoint(
          date: DateTime.parse(row.read<String>('report_date')),
          revenueCentavos: dayRevenue,
          cogsCentavos: dayCogs,
          expensesCentavos: dayExpenses,
          netProfitCentavos: dayRevenue - dayCogs - dayExpenses,
        );
      }).toList(),
      expenseCategories: categoryRows.map((row) {
        return ExpenseCategoryTotal(
          category: row.read<String>('category'),
          amountCentavos: row.read<int>('amount'),
        );
      }).toList(),
      topProducts: productRows.map((row) {
        final productRevenue = row.read<int>('revenue');
        final productCogs = row.read<int>('cogs');
        return ProductProfit(
          productName: row.read<String>('product_name'),
          quantitySold: row.read<int>('quantity_sold'),
          revenueCentavos: productRevenue,
          cogsCentavos: productCogs,
          grossProfitCentavos: productRevenue - productCogs,
        );
      }).toList(),
    );
  }
}
