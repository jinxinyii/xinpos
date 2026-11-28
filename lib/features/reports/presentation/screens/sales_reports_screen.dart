import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';
import 'package:printing/printing.dart';

import '../../domain/entities/sales_report.dart';
import '../../domain/entities/sales_report_filter.dart';
import '../../data/services/sales_report_pdf_service.dart';
import '../providers/sales_report_providers.dart';

class SalesReportsScreen extends ConsumerStatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  ConsumerState<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends ConsumerState<SalesReportsScreen> {
  late SalesReportFilter _filter;
  String _selectedPeriod = 'Today';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _filter = SalesReportFilter(startDate: now, endDate: now);
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

    switch (period) {
      case 'Today':
        start = today;
        break;
      case 'Yesterday':
        start = today.subtract(const Duration(days: 1));
        break;
      case 'This week':
        start = today.subtract(Duration(days: today.weekday - 1));
        break;
      case 'This month':
        start = DateTime(today.year, today.month);
        break;
      default:
        start = today;
    }

    setState(() {
      _selectedPeriod = period;
      _filter = SalesReportFilter(
        startDate: start,
        endDate: period == 'Yesterday' ? start : today,
      );
    });
  }

  Future<void> _chooseDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _filter.startDate,
        end: _filter.endDate.isAfter(DateTime.now())
            ? DateTime.now()
            : _filter.endDate,
      ),
    );

    if (!mounted || range == null) return;

    setState(() {
      _selectedPeriod = 'Custom';
      _filter = SalesReportFilter(startDate: range.start, endDate: range.end);
    });
  }

  Future<Uint8List> _buildPdf(SalesReport data) async {
    final bytes = await SalesReportPdfService().build(
      report: data,
      filter: _filter,
    );
    return Uint8List.fromList(bytes);
  }

  Future<void> _sharePdf(SalesReport data) async {
    try {
      final bytes = await _buildPdf(data);
      if (!mounted) return;
      await Printing.sharePdf(
        bytes: bytes,
        filename: SalesReportPdfService.filename(_filter),
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

  Future<void> _printPdf(SalesReport data) async {
    try {
      final bytes = await _buildPdf(data);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: SalesReportPdfService.filename(_filter),
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

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(salesReportProvider(_filter));
    final colors = Theme.of(context).colorScheme;
    final dateText = _filter.startDate == _filter.endDate
        ? DateFormat('MMMM d, yyyy').format(_filter.startDate)
        : '${DateFormat('MMM d').format(_filter.startDate)} – ${DateFormat('MMM d, yyyy').format(_filter.endDate)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        actions: [
          IconButton(
            tooltip: 'Refresh Report',
            onPressed: () => ref.invalidate(salesReportProvider(_filter)),
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
                const Icon(Icons.error_outline, size: 44),
                const SizedBox(height: 12),
                const Text('Unable to load sales report.'),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(salesReportProvider(_filter)),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(salesReportProvider(_filter)),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 800;
              final horizontalPadding = wide ? 28.0 : 16.0;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  12,
                  horizontalPadding,
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
                      ])
                        ChoiceChip(
                          label: Text(period),
                          selected: _selectedPeriod == period,
                          onSelected: (_) => _setPeriod(period),
                        ),
                      OutlinedButton.icon(
                        onPressed: _chooseDateRange,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _selectedPeriod == 'Custom'
                              ? 'Custom range'
                              : 'Date range',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    dateText,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: colors.onSurfaceVariant),
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
                  _MetricGrid(
                    wide: wide,
                    metrics: [
                      _MetricData(
                        'Total Revenue',
                        _money(data.totalRevenueCentavos),
                        Icons.payments_outlined,
                      ),
                      _MetricData(
                        'Transactions',
                        data.transactionCount.toString(),
                        Icons.receipt_long_outlined,
                      ),
                      _MetricData(
                        'Items Sold',
                        data.totalItemsSold.toString(),
                        Icons.shopping_bag_outlined,
                      ),
                      _MetricData(
                        'Average Sale',
                        _money(data.averageTransactionCentavos),
                        Icons.trending_up,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ReportSection(
                    title: 'Daily Sales',
                    subtitle: 'Revenue by day',
                    child: data.dailySales.isEmpty
                        ? const _EmptyReport(
                            message: 'No sales recorded for this period.',
                          )
                        : _DailySalesChart(
                            points: data.dailySales,
                            money: _money,
                            dateLabel: _dateLabel,
                          ),
                  ),
                  const SizedBox(height: 16),
                  _ReportSection(
                    title: 'Top-Selling Products',
                    subtitle: 'Top 10 products by quantity sold',
                    child: data.topProducts.isEmpty
                        ? const _EmptyReport(
                            message: 'No product sales for this period.',
                          )
                        : Column(
                            children: data.topProducts.asMap().entries.map((
                              entry,
                            ) {
                              final item = entry.value;
                              return _RankedReportRow(
                                rank: entry.key + 1,
                                title: item.productName,
                                subtitle: '${item.quantitySold} sold',
                                trailing: _money(item.revenueCentavos),
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PaymentSection(data: data, money: _money),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _CategorySection(data: data, money: _money),
                        ),
                      ],
                    )
                  else ...[
                    _PaymentSection(data: data, money: _money),
                    const SizedBox(height: 16),
                    _CategorySection(data: data, money: _money),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;

  const _MetricData(this.label, this.value, this.icon);
}

class _MetricGrid extends StatelessWidget {
  final bool wide;
  final List<_MetricData> metrics;

  const _MetricGrid({required this.wide, required this.metrics});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = wide ? 4 : (width >= 500 ? 2 : 2);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 112,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        final colors = Theme.of(context).colorScheme;
        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(metric.icon, color: colors.primary, size: 21),
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  metric.label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ReportSection({
    required this.title,
    required this.subtitle,
    required this.child,
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
    final maxRevenue = points.fold<int>(
      0,
      (max, point) => point.revenueCentavos > max ? point.revenueCentavos : max,
    );
    final visible = points.length > 14
        ? points.sublist(points.length - 14)
        : points;

    return Column(
      children: visible.map((point) {
        final ratio = maxRevenue == 0
            ? 0.0
            : point.revenueCentavos / maxRevenue;
        return Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(
            children: [
              SizedBox(
                width: 52,
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
                    value: ratio.clamp(0.0, 1.0).toDouble(),
                    minHeight: 10,
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
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _RankedReportRow extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String trailing;

  const _RankedReportRow({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          if (rank > 0)
            SizedBox(
              width: 30,
              child: Text(
                '$rank',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _PaymentSection extends StatelessWidget {
  final SalesReport data;
  final String Function(int) money;

  const _PaymentSection({required this.data, required this.money});

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      title: 'Payment Methods',
      subtitle: 'Revenue by payment type',
      child: data.paymentMethods.isEmpty
          ? const _EmptyReport(message: 'No payment data for this period.')
          : Column(
              children: data.paymentMethods
                  .map(
                    (item) => _RankedReportRow(
                      rank: 0,
                      title: item.method.toUpperCase(),
                      subtitle: '${item.transactionCount} transactions',
                      trailing: money(item.amountCentavos),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final SalesReport data;
  final String Function(int) money;

  const _CategorySection({required this.data, required this.money});

  @override
  Widget build(BuildContext context) {
    return _ReportSection(
      title: 'Sales by Category',
      subtitle: 'Revenue grouped by current product category',
      child: data.categorySales.isEmpty
          ? const _EmptyReport(message: 'No category data for this period.')
          : Column(
              children: data.categorySales
                  .map(
                    (item) => _RankedReportRow(
                      rank: 0,
                      title: item.categoryName,
                      subtitle: '${item.quantitySold} items',
                      trailing: money(item.revenueCentavos),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  final String message;

  const _EmptyReport({required this.message});

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
