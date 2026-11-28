import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../reports/domain/entities/sales_report.dart';
import '../../../reports/domain/entities/sales_report_filter.dart';
import '../../../reports/presentation/providers/sales_report_providers.dart';
import '../../domain/entities/dashboard_data.dart';
import '../providers/dashboard_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late SalesReportFilter _filter;
  String _selectedPeriod = 'This month';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filter = SalesReportFilter(
      startDate: DateTime(now.year, now.month),
      endDate: now,
    );
  }

  String _money(int centavos) {
    return NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(centavos / 100);
  }

  String _dateLabel(DateTime date) => DateFormat('MMM d').format(date);

  void _setPeriod(String period) {
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
      default:
        start = DateTime(today.year, today.month);
        end = today;
        break;
    }

    setState(() {
      _selectedPeriod = period;
      _filter = SalesReportFilter(startDate: start, endDate: end);
    });
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
      _selectedPeriod = 'Custom';
      _filter = SalesReportFilter(startDate: range.start, endDate: range.end);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(dashboardDataProvider);
    ref.invalidate(salesReportProvider(_filter));
    await Future.wait([
      ref.read(dashboardDataProvider.future),
      ref.read(salesReportProvider(_filter).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardDataProvider);
    final report = ref.watch(salesReportProvider(_filter));
    final theme = Theme.of(context);
    final todayLabel = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('xinPOS', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              'Business Overview',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Dashboard',
            onPressed: () {
              ref.invalidate(dashboardDataProvider);
              ref.invalidate(salesReportProvider(_filter));
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 800;
            final padding = wide ? 28.0 : 16.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(padding, 16, padding, 28),
              children: [
                Text(
                  'Dashboard',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  todayLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  "Today's Sales",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                dashboard.when(
                  loading: () => const _LoadingPanel(),
                  error: (error, stackTrace) => _ErrorPanel(
                    message: 'Unable to load today’s sales.',
                    onRetry: () => ref.invalidate(dashboardDataProvider),
                  ),
                  data: (data) =>
                      _TodayOverview(data: data, money: _money, wide: wide),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sales Analytics',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.go('/sales/reports'),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: const Text('Full Report'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final period in [
                      'Today',
                      'Yesterday',
                      'This week',
                      'This month',
                    ])
                      ChoiceChip(
                        label: Text(period),
                        selected: _selectedPeriod == period,
                        onSelected: (_) => _setPeriod(period),
                      ),
                    OutlinedButton.icon(
                      onPressed: _chooseDateRange,
                      icon: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: Text(
                        _selectedPeriod == 'Custom'
                            ? 'Custom range'
                            : 'Date range',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _filter.startDate == _filter.endDate
                      ? DateFormat('MMMM d, yyyy').format(_filter.startDate)
                      : '${DateFormat('MMM d').format(_filter.startDate)} – ${DateFormat('MMM d, yyyy').format(_filter.endDate)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                report.when(
                  loading: () => const _LoadingPanel(),
                  error: (error, stackTrace) => _ErrorPanel(
                    message: 'Unable to load sales analytics.',
                    onRetry: () => ref.invalidate(salesReportProvider(_filter)),
                  ),
                  data: (data) => _SalesAnalytics(
                    report: data,
                    money: _money,
                    dateLabel: _dateLabel,
                    wide: wide,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TodayOverview extends StatelessWidget {
  final DashboardData data;
  final String Function(int) money;
  final bool wide;

  const _TodayOverview({
    required this.data,
    required this.money,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        'Total Sales',
        money(data.totalSalesCentavos),
        Icons.payments_rounded,
        const Color(0xFF2563EB),
      ),
      _MetricData(
        'Transactions',
        data.transactionCount.toString(),
        Icons.receipt_long_rounded,
        const Color(0xFF0D9488),
      ),
      _MetricData(
        'Cash Sales',
        money(data.cashSalesCentavos),
        Icons.money_rounded,
        const Color(0xFF16A34A),
      ),
      _MetricData(
        'GCash Sales',
        money(data.gcashSalesCentavos),
        Icons.account_balance_wallet_rounded,
        const Color(0xFF7C3AED),
      ),
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 124,
          ),
          itemBuilder: (context, index) {
            final item = metrics[index];
            return DashboardMetricCard(
              title: item.title,
              value: item.value,
              icon: item.icon,
              color: item.color,
            );
          },
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: "Today's Recent Sales",
          trailing: TextButton(
            onPressed: () => context.go('/sales'),
            child: const Text('View All'),
          ),
          child: data.recentSales.isEmpty
              ? const _EmptyState(
                  message: 'No transactions today. Completed sales will appear here.',
                )
              : Column(
                  children: data.recentSales.map((sale) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => context.go('/sales/${sale.id}'),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .secondaryContainer,
                        foregroundColor: Theme.of(context)
                            .colorScheme
                            .onSecondaryContainer,
                        child: const Icon(Icons.receipt_outlined),
                      ),
                      title: Text(
                        sale.receiptNumber,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${DateFormat('h:mm a').format(sale.soldAt)} · ${sale.paymentMethod.isEmpty ? sale.status : sale.paymentMethod}',
                      ),
                      trailing: Text(
                        money(sale.totalCentavos),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

class _SalesAnalytics extends StatelessWidget {
  final SalesReport report;
  final String Function(int) money;
  final String Function(DateTime) dateLabel;
  final bool wide;

  const _SalesAnalytics({
    required this.report,
    required this.money,
    required this.dateLabel,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        'Revenue',
        money(report.totalRevenueCentavos),
        Icons.trending_up_rounded,
        const Color(0xFF2563EB),
      ),
      _MetricData(
        'Transactions',
        report.transactionCount.toString(),
        Icons.receipt_long_rounded,
        const Color(0xFF0D9488),
      ),
      _MetricData(
        'Items Sold',
        report.totalItemsSold.toString(),
        Icons.shopping_bag_outlined,
        const Color(0xFF16A34A),
      ),
      _MetricData(
        'Average Sale',
        money(report.averageTransactionCentavos),
        Icons.show_chart_rounded,
        const Color(0xFF7C3AED),
      ),
    ];

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: metrics.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 124,
          ),
          itemBuilder: (context, index) {
            final item = metrics[index];
            return DashboardMetricCard(
              title: item.title,
              value: item.value,
              icon: item.icon,
              color: item.color,
            );
          },
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: 'Sales Trend',
          subtitle: 'Daily revenue for the selected period',
          child: report.dailySales.isEmpty
              ? const _EmptyState(message: 'No sales recorded for this period.')
              : _DailySalesChart(
                  points: report.dailySales,
                  money: money,
                  dateLabel: dateLabel,
                ),
        ),
        const SizedBox(height: 14),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SectionCard(
                  title: 'Best-Selling Products',
                  subtitle: 'Top products by quantity sold',
                  child: _TopProducts(
                    products: report.topProducts,
                    money: money,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _SectionCard(
                  title: 'Payment Breakdown',
                  subtitle: 'Revenue by payment method',
                  child: _PaymentBreakdown(
                    methods: report.paymentMethods,
                    money: money,
                  ),
                ),
              ),
            ],
          )
        else ...[
          _SectionCard(
            title: 'Best-Selling Products',
            subtitle: 'Top products by quantity sold',
            child: _TopProducts(products: report.topProducts, money: money),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Payment Breakdown',
            subtitle: 'Revenue by payment method',
            child: _PaymentBreakdown(
              methods: report.paymentMethods,
              money: money,
            ),
          ),
        ],
      ],
    );
  }
}

class _DailySalesChart extends StatelessWidget {
  final List<DailySalesPoint> points;
  final String Function(int) money;
  final String Function(DateTime) dateLabel;

  const _DailySalesChart({
    required this.points,
    required this.money,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final visible = points.length > 14
        ? points.sublist(points.length - 14)
        : points;
    final maximum = visible.fold<int>(
      0,
      (current, point) =>
          point.revenueCentavos > current ? point.revenueCentavos : current,
    );

    return Column(
      children: visible.map((point) {
        final ratio = maximum == 0
            ? 0.0
            : (point.revenueCentavos / maximum).clamp(0.0, 1.0).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              SizedBox(
                width: 54,
                child: Text(
                  dateLabel(point.date),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 11,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Text(
                  money(point.revenueCentavos),
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TopProducts extends StatelessWidget {
  final List<TopProductSales> products;
  final String Function(int) money;

  const _TopProducts({required this.products, required this.money});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _EmptyState(message: 'No product sales for this period.');
    }

    return Column(
      children: products.take(5).toList().asMap().entries.map((entry) {
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
                      '${product.quantitySold} sold',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                money(product.revenueCentavos),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PaymentBreakdown extends StatelessWidget {
  final List<PaymentMethodSales> methods;
  final String Function(int) money;

  const _PaymentBreakdown({required this.methods, required this.money});

  @override
  Widget build(BuildContext context) {
    if (methods.isEmpty) {
      return const _EmptyState(message: 'No payment data for this period.');
    }

    final total = methods.fold<int>(
      0,
      (sum, method) => sum + method.amountCentavos,
    );

    return Column(
      children: methods.map((method) {
        final ratio = total == 0
            ? 0.0
            : (method.amountCentavos / total).clamp(0.0, 1.0).toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      method.method.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    money(method.amountCentavos),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${method.transactionCount} transactions · ${(ratio * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _MetricData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricData(this.title, this.value, this.icon, this.color);
}

class DashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const DashboardMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Something Went Wrong',
      child: Column(
        children: [
          Text(message),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}
