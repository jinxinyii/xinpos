import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';
import 'package:printing/printing.dart';

import '../../domain/entities/profit_report.dart';
import '../../domain/entities/sales_report_filter.dart';
import '../../data/services/profit_report_pdf_service.dart';
import '../providers/profit_report_providers.dart';

class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  late SalesReportFilter _filter;
  String _period = 'This month';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _filter = SalesReportFilter(startDate: today, endDate: today);
    _setPeriod('This month', rebuild: false);
  }

  String _money(int centavos) => NumberFormat.currency(
    locale: 'en_PH',
    symbol: '₱',
    decimalDigits: 2,
  ).format(centavos / 100);

  void _setPeriod(String period, {bool rebuild = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    late DateTime start;
    late DateTime end;

    switch (period) {
      case 'Today':
        start = today;
        end = today;
        break;
      case 'Yesterday':
        start = today.subtract(const Duration(days: 1));
        end = start;
        break;
      case 'This week':
        start = today.subtract(Duration(days: today.weekday - 1));
        end = today;
        break;
      case 'This month':
        start = DateTime(today.year, today.month);
        end = today;
        break;
      default:
        start = DateTime(2000);
        end = today;
    }

    void update() {
      _period = period;
      _filter = SalesReportFilter(startDate: start, endDate: end);
    }

    if (rebuild) {
      setState(update);
    } else {
      update();
    }
  }

  Future<void> _chooseDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: _filter.startDate,
        end: _filter.endDate.isAfter(now) ? now : _filter.endDate,
      ),
    );

    if (!mounted || range == null) return;
    setState(() {
      _period = 'Custom';
      _filter = SalesReportFilter(startDate: range.start, endDate: range.end);
    });
  }

  Future<Uint8List> _buildPdf(ProfitReport data) async {
    final bytes = await ProfitReportPdfService().build(
      report: data,
      filter: _filter,
    );
    return Uint8List.fromList(bytes);
  }

  Future<void> _sharePdf(ProfitReport data) async {
    try {
      final bytes = await _buildPdf(data);
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: ProfitReportPdfService.filename(_filter),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          AppSnackBar(
            context: context,
            content: Text('Unable to share PDF: $error'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  Future<void> _printPdf(ProfitReport data) async {
    try {
      final bytes = await _buildPdf(data);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: ProfitReportPdfService.filename(_filter),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          AppSnackBar(
            context: context,
            content: Text('Unable to print PDF: $error'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }

  Widget _metric({
    required String label,
    required int amount,
    required IconData icon,
    bool emphasized = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: emphasized ? colors.primaryContainer : colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              icon,
              color: emphasized ? colors.onPrimaryContainer : colors.primary,
            ),
            Text(
              _money(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: emphasized ? colors.onPrimaryContainer : null,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: emphasized
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _comparisonChart(List<DailyProfitPoint> points) {
    final visible = points.length > 14
        ? points.sublist(points.length - 14)
        : points;
    final maxValue = visible.fold<int>(0, (value, point) {
      final candidate = [
        point.revenueCentavos,
        point.cogsCentavos + point.expensesCentavos,
      ].reduce((a, b) => a > b ? a : b);
      return candidate > value ? candidate : value;
    });
    if (visible.isEmpty) {
      return const _EmptyState(
        message: 'No financial activity for this period.',
      );
    }

    return Column(
      children: [
        Row(
          children: [
            _legend(Theme.of(context).colorScheme.primary, 'Revenue'),
            const SizedBox(width: 16),
            _legend(Theme.of(context).colorScheme.tertiary, 'Costs + expenses'),
          ],
        ),
        const SizedBox(height: 16),
        for (final point in visible) ...[
          Row(
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  DateFormat('MMM d').format(point.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    _bar(
                      point.revenueCentavos,
                      maxValue,
                      Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 5),
                    _bar(
                      point.cogsCentavos + point.expensesCentavos,
                      maxValue,
                      Theme.of(context).colorScheme.tertiary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 88,
                child: Text(
                  _money(point.netProfitCentavos),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: point.netProfitCentavos < 0
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _bar(int value, int maximum, Color color) {
    final ratio = maximum <= 0
        ? 0.0
        : (value / maximum).clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 9,
        color: color,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _categoryBreakdown(List<ExpenseCategoryTotal> categories) {
    if (categories.isEmpty) {
      return const _EmptyState(
        message: 'No expenses recorded for this period.',
      );
    }
    final total = categories.fold<int>(
      0,
      (sum, item) => sum + item.amountCentavos,
    );
    return Column(
      children: categories.map((item) {
        final ratio = total == 0 ? 0.0 : item.amountCentavos / total;
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.category,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _money(item.amountCentavos),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(ratio * 100).toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              _bar(
                item.amountCentavos,
                total,
                Theme.of(context).colorScheme.tertiary,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _topProducts(List<ProductProfit> products) {
    if (products.isEmpty) {
      return const _EmptyState(message: 'No product sales for this period.');
    }
    return Column(
      children: products.asMap().entries.map((entry) {
        final product = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${entry.key + 1}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${product.quantitySold} sold · Revenue ${_money(product.revenueCentavos)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _money(product.grossProfitCentavos),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: product.grossProfitCentavos < 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                  Text(
                    'Gross profit',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _content(ProfitReport report, bool wide) {
    final netColor = report.netProfitCentavos < 0
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: wide ? 3 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: wide ? 2.2 : 1.55,
          children: [
            _metric(
              label: 'Revenue',
              amount: report.revenueCentavos,
              icon: Icons.payments_outlined,
            ),
            _metric(
              label: 'Cost of Goods Sold',
              amount: report.costOfGoodsSoldCentavos,
              icon: Icons.inventory_2_outlined,
            ),
            _metric(
              label: 'Gross Profit',
              amount: report.grossProfitCentavos,
              icon: Icons.trending_up,
            ),
            _metric(
              label: 'Operating Expenses',
              amount: report.operatingExpensesCentavos,
              icon: Icons.money_off_csred_outlined,
            ),
            _metric(
              label: 'Net Profit',
              amount: report.netProfitCentavos,
              icon: Icons.account_balance_wallet_outlined,
              emphasized: true,
            ),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.percent),
                    Text(
                      '${report.profitMarginPercent.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: netColor,
                      ),
                    ),
                    const Text('Net Profit Margin'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _section(
          title: 'Revenue vs. Costs',
          subtitle: 'Daily revenue compared with cost of goods and operating expenses. Net profit is shown at the right.',
          child: _comparisonChart(report.dailyProfit),
        ),
        const SizedBox(height: 16),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _section(
                  title: 'Expense Breakdown',
                  subtitle: 'Operating expenses by category',
                  child: _categoryBreakdown(report.expenseCategories),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _section(
                  title: 'Best-Performing Products',
                  subtitle: 'Top 10 products by gross profit',
                  child: _topProducts(report.topProducts),
                ),
              ),
            ],
          )
        else ...[
          _section(
            title: 'Expense Breakdown',
            subtitle: 'Operating expenses by category',
            child: _categoryBreakdown(report.expenseCategories),
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Best-Performing Products',
            subtitle: 'Top 10 products by gross profit',
            child: _topProducts(report.topProducts),
          ),
        ],
        const SizedBox(height: 16),
        _section(
          title: 'Business Activity',
          subtitle: 'Summary for the selected period',
          child: Column(
            children: [
              _summaryRow(
                'Completed transactions',
                report.transactionCount.toString(),
              ),
              _summaryRow('Items sold', report.itemsSold.toString()),
              _summaryRow('Gross profit', _money(report.grossProfitCentavos)),
              _summaryRow(
                'Operating expenses',
                _money(report.operatingExpensesCentavos),
              ),
              const Divider(height: 22),
              _summaryRow(
                'Net result',
                _money(report.netProfitCentavos),
                strong: true,
                color: netColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'COGS uses the historical unit cost saved with each sale item. Expenses are grouped by their recorded expense dates. This report excludes taxes, refunds, owner withdrawals, and unrecorded adjustments.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool strong = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(profitReportProvider(_filter));
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profit Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(profitReportProvider(_filter)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: report.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                const Text('Unable to load profit dashboard.'),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(profitReportProvider(_filter)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(profitReportProvider(_filter)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              wide ? 28 : 16,
              16,
              wide ? 28 : 16,
              28,
            ),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final period in [
                    'Today',
                    'Yesterday',
                    'This week',
                    'This month',
                    'All',
                  ])
                    ChoiceChip(
                      label: Text(period),
                      selected: _period == period,
                      onSelected: (_) => _setPeriod(period),
                    ),
                  OutlinedButton.icon(
                    onPressed: _chooseDateRange,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                    label: Text(
                      _period == 'Custom' ? 'Custom range' : 'Date range',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _sharePdf(data),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Share PDF'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _printPdf(data),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('Print / Save PDF'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _content(data, wide),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
