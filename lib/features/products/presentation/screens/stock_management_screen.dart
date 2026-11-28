import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';

import '../providers/inventory_management_provider.dart';
import '../providers/inventory_providers.dart';
import '../providers/product_details_provider.dart';

class StockManagementScreen extends ConsumerWidget {
  final String productId;

  const StockManagementScreen({required this.productId, super.key});

  Future<void> _manageStock(
    BuildContext context,
    WidgetRef ref,
    String movementType,
  ) async {
    final result = await showDialog<_MovementInput>(
      context: context,
      builder: (_) => _MovementDialog(movementType: movementType),
    );

    if (result == null || !context.mounted) return;

    try {
      final service = ref.read(inventoryManagementServiceProvider);

      switch (movementType) {
        case 'stock_in':
          await service.stockIn(
            productId: productId,
            quantity: result.quantity,
            note: result.note,
          );
        case 'stock_out':
          await service.stockOut(
            productId: productId,
            quantity: result.quantity,
            note: result.note,
          );
        case 'stock_adjustment':
          await service.adjustStock(
            productId: productId,
            countedQuantity: result.quantity,
            note: result.note,
          );
      }

      ref.invalidate(stockQuantityProvider(productId));
      ref.invalidate(inventoryMovementsProvider(productId));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Inventory updated successfully.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(context: context, content: Text(error.toString())),
      );
    }
  }

  String _movementLabel(String type) {
    switch (type) {
      case 'stock_in':
        return 'Stock In';
      case 'stock_out':
        return 'Stock Out';
      case 'stock_adjustment':
        return 'Stock Adjustment';
      case 'opening_stock':
        return 'Opening Stock';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(productDetailsProvider(productId));
    final stockState = ref.watch(stockQuantityProvider(productId));
    final movementsState = ref.watch(inventoryMovementsProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Stock Management')),
      body: productState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load product: $error')),
        data: (product) {
          if (product == null || !product.isActive) {
            return const Center(child: Text('Product not found.'));
          }

          if (!product.trackInventory) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Inventory tracking is disabled for this product.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(stockQuantityProvider(productId));
              ref.invalidate(inventoryMovementsProvider(productId));
              await ref.read(stockQuantityProvider(productId).future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          product.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        stockState.when(
                          loading: () => const CircularProgressIndicator(),
                          error: (error, stackTrace) =>
                              const Text('Unable to load stock quantity.'),
                          data: (quantity) => Column(
                            children: [
                              Text(
                                '$quantity',
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: quantity <= product.reorderLevel
                                          ? Theme.of(context).colorScheme.error
                                          : Theme.of(context)
                                                .colorScheme
                                                .primary,
                                    ),
                              ),
                              const Text('Current Stock'),
                              const SizedBox(height: 8),
                              Text(
                                'Low stock alert: ${product.reorderLevel} units',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (quantity <= product.reorderLevel)
                                Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Chip(
                                    avatar: const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Low Stock'),
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .errorContainer,
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
                  'Manage Quantity',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _manageStock(context, ref, 'stock_in'),
                        icon: const Icon(Icons.add),
                        label: const Text('Stock In'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _manageStock(context, ref, 'stock_out'),
                        icon: const Icon(Icons.remove),
                        label: const Text('Stock Out'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      _manageStock(context, ref, 'stock_adjustment'),
                  icon: const Icon(Icons.tune),
                  label: const Text('Adjust Physical Count'),
                ),
                const SizedBox(height: 24),
                Text(
                  'Movement History',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                movementsState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      Text('Unable to load movement history: $error'),
                  data: (movements) {
                    if (movements.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text('No stock movements recorded yet.'),
                          ),
                        ),
                      );
                    }

                    return Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: movements.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final movement = movements[index];
                          final isIncrease = movement.quantityDelta > 0;

                          final date = DateFormat('MMM d, yyyy • h:mm a')
                              .format(
                                DateTime.fromMillisecondsSinceEpoch(
                                  movement.createdAt,
                                ),
                              );

                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                isIncrease
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: isIncrease
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                            title: Text(_movementLabel(movement.movementType)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(date),
                                if (movement.note != null &&
                                    movement.note!.isNotEmpty)
                                  Text(movement.note!),
                              ],
                            ),
                            trailing: Text(
                              '${isIncrease ? '+' : ''}${movement.quantityDelta}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isIncrease
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MovementInput {
  final int quantity;
  final String? note;

  const _MovementInput({required this.quantity, this.note});
}

class _MovementDialog extends StatefulWidget {
  final String movementType;

  const _MovementDialog({required this.movementType});

  @override
  State<_MovementDialog> createState() => _MovementDialogState();
}

class _MovementDialogState extends State<_MovementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.movementType) {
      case 'stock_in':
        return 'Stock In';
      case 'stock_out':
        return 'Stock Out';
      default:
        return 'Adjust Physical Count';
    }
  }

  String get _quantityLabel {
    return widget.movementType == 'stock_adjustment'
        ? 'Actual counted quantity'
        : 'Quantity';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final quantity = int.parse(_quantityController.text.trim());
    final note = _noteController.text.trim();

    Navigator.pop(
      context,
      _MovementInput(quantity: quantity, note: note.isEmpty ? null : note),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdjustment = widget.movementType == 'stock_adjustment';

    return AlertDialog(
      title: Text(_title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _quantityController,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _quantityLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final quantity = int.tryParse(value?.trim() ?? '');

                if (quantity == null) {
                  return 'Enter a valid whole number.';
                }

                if (isAdjustment ? quantity < 0 : quantity <= 0) {
                  return isAdjustment
                      ? 'Quantity cannot be negative.'
                      : 'Quantity must be greater than zero.';
                }

                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Reason for this stock movement',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
