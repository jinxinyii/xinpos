import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/app_notification.dart';

import '../../domain/entities/sale_detail.dart';
import '../../../settings/data/services/bluetooth_printer_service.dart';
import '../providers/sale_providers.dart';

class SaleDetailsScreen extends ConsumerStatefulWidget {
  final String saleId;

  const SaleDetailsScreen({super.key, required this.saleId});

  @override
  ConsumerState<SaleDetailsScreen> createState() => _SaleDetailsScreenState();
}

class _SaleDetailsScreenState extends ConsumerState<SaleDetailsScreen> {
  bool _printing = false;

  Future<void> _printReceipt(SaleDetail sale) async {
    if (_printing) return;
    setState(() => _printing = true);

    try {
      final printed = await BluetoothPrinterService().printSaleReceipt(sale);
      if (!mounted) return;
      setState(() => _printing = false);
      AppNotification.show(
        context,
        message: printed
            ? 'Receipt sent to printer'
            : 'Unable to print receipt',
        type: printed ? AppNotificationType.success : AppNotificationType.error,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _printing = false);
      AppNotification.show(
        context,
        message: 'Print failed: $error',
        type: AppNotificationType.error,
      );
    }
  }

  String _formatPrice(int centavos) {
    return NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(centavos / 100);
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleDetailsProvider(widget.saleId));
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Details'),
        actions: [
          IconButton(
            tooltip: 'Refresh receipt',
            onPressed: () => ref.invalidate(saleDetailsProvider(widget.saleId)),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: saleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Unable to load receipt details.'),
                const SizedBox(height: 8),
                Text('$error', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(saleDetailsProvider(widget.saleId)),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (sale) {
          if (sale == null) {
            return const Center(child: Text('Receipt not found.'));
          }

          final date = DateFormat('MMMM d, yyyy • h:mm a').format(sale.soldAt);
          final wide = MediaQuery.sizeOf(context).width >= 760;

          final receipt = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Sale Completed',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sale.receiptNumber,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (sale.queueCode != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'QUEUE NUMBER',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colors.onPrimaryContainer,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sale.queueCode!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: colors.onPrimaryContainer,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          date,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Chip(label: Text(sale.status.toUpperCase())),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Items Purchased',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        for (var index = 0; index < sale.items.length; index++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == sale.items.length - 1 ? 0 : 14,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sale.items[index].productName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${sale.items[index].quantity} × ${_formatPrice(sale.items[index].unitPriceCentavos)}'
                                        '${sale.items[index].sku == null || sale.items[index].sku!.isEmpty ? '' : ' • ${sale.items[index].sku}'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: colors.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatPrice(
                                    sale.items[index].lineTotalCentavos,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Payment Summary',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _AmountRow(
                          label: 'Subtotal',
                          value: _formatPrice(sale.subtotalCentavos),
                        ),
                        if (sale.discountCentavos > 0)
                          _AmountRow(
                            label: 'Discount',
                            value: '-${_formatPrice(sale.discountCentavos)}',
                          ),
                        const Divider(height: 24),
                        _AmountRow(
                          label: 'Total',
                          value: _formatPrice(sale.totalCentavos),
                          emphasized: true,
                        ),
                        const Divider(height: 24),
                        _AmountRow(
                          label: 'Payment Method',
                          value:
                              sale.payment?.method.toUpperCase() ??
                              'Unavailable',
                        ),
                        if (sale.payment != null) ...[
                          _AmountRow(
                            label: 'Amount Paid',
                            value: _formatPrice(sale.payment!.amountCentavos),
                          ),
                          if (sale.payment!.referenceNumber != null &&
                              sale.payment!.referenceNumber!.isNotEmpty)
                            _AmountRow(
                              label: 'Reference Number',
                              value: sale.payment!.referenceNumber!,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _printing ? null : () => _printReceipt(sale),
                    icon: _printing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_rounded),
                    label: Text(_printing ? 'Printing...' : 'Print Receipt'),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );

          return Center(
            child: wide
                ? receipt
                : SizedBox(width: double.infinity, child: receipt),
          );
        },
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}
