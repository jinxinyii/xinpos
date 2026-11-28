import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';

import '../providers/category_providers.dart';
import '../providers/inventory_providers.dart';
import '../providers/product_details_provider.dart';
import '../providers/product_management_provider.dart';
import '../providers/products_list_provider.dart';

class ProductDetailsScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailsScreen({required this.productId, super.key});

  String _formatPrice(int centavos) {
    return NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(centavos / 100);
  }

  String _formatDate(int timestamp) {
    return DateFormat('MMM d, yyyy • h:mm a')
        .format(DateTime.fromMillisecondsSinceEpoch(timestamp));
  }

  Future<void> _archiveProduct(
    BuildContext context,
    WidgetRef ref,
    String productName,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive Product?'),
        content: Text(
          'Are you sure you want to archive "$productName"? '
          'It will no longer appear in the active product list. '
          'Its sales and inventory history will be preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(productManagementServiceProvider)
          .archiveProduct(productId);

      ref.invalidate(productDetailsProvider(productId));
      ref.invalidate(productsListProvider);
      ref.invalidate(stockQuantityProvider(productId));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Product archived successfully.'),
        ),
      );

      context.pop(true);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(context: context, content: Text(error.toString())),
      );
    }
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(productDetailsProvider(productId));
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Product Details')),
      body: productState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text('Unable to load product details.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () {
                    ref.invalidate(productDetailsProvider(productId));
                  },
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (product) {
          if (product == null || !product.isActive) {
            return const Center(
              child: Text('Product not found or has been archived.'),
            );
          }

          final categoryName = categoriesState.when(
            loading: () => 'Loading...',
            error: (error, stackTrace) => 'Unavailable',
            data: (categories) {
              if (product.categoryId == null) return 'Uncategorized';

              for (final category in categories) {
                if (category.id == product.categoryId) {
                  return category.name;
                }
              }

              return 'Uncategorized';
            },
          );

          final stockState = product.trackInventory
              ? ref.watch(stockQuantityProvider(product.id))
              : null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 34,
                        child: Icon(
                          product.trackInventory
                              ? Icons.inventory_2_outlined
                              : Icons.shopping_bag_outlined,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        product.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      if (product.sku != null && product.sku!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'SKU: ${product.sku}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        _formatPrice(product.sellingPriceCentavos),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _detailRow(context, 'Category', categoryName),
                      _detailRow(
                        context,
                        'Description',
                        product.description?.isNotEmpty == true
                            ? product.description!
                            : 'No description',
                      ),
                      _detailRow(
                        context,
                        'Cost Price',
                        _formatPrice(product.costPriceCentavos),
                      ),
                      _detailRow(
                        context,
                        'Selling Price',
                        _formatPrice(product.sellingPriceCentavos),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _detailRow(
                        context,
                        'Tracking',
                        product.trackInventory ? 'Enabled' : 'Disabled',
                      ),
                      if (product.trackInventory) ...[
                        stockState!.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, stackTrace) =>
                              const Text('Unable to load current stock.'),
                          data: (quantity) {
                            final isLow = quantity <= product.reorderLevel;

                            return Column(
                              children: [
                                _detailRow(
                                  context,
                                  'Current Stock',
                                  '$quantity units',
                                ),
                                _detailRow(
                                  context,
                                  'Low Stock Alert',
                                  '${product.reorderLevel} units',
                                ),
                                if (isLow)
                                  Align(
                                    alignment: Alignment.centerLeft,
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
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const Divider(height: 24),
                      _detailRow(
                        context,
                        'Created',
                        _formatDate(product.createdAt),
                      ),
                      _detailRow(
                        context,
                        'Last Updated',
                        _formatDate(product.updatedAt),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (product.trackInventory) ...[
                FilledButton.icon(
                  onPressed: () async {
                    await context.push('/products/${product.id}/stock');
                    ref.invalidate(productDetailsProvider(productId));
                    ref.invalidate(stockQuantityProvider(productId));
                  },
                  icon: const Icon(Icons.inventory_outlined),
                  label: const Text('Manage Stock'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  await context.push('/products/${product.id}/barcodes');
                },
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Manage Barcodes'),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  await context.push('/products/${product.id}/edit');
                  ref.invalidate(productDetailsProvider(productId));
                  ref.invalidate(productsListProvider);
                  ref.invalidate(stockQuantityProvider(productId));
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Product'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _archiveProduct(context, ref, product.name),
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archive Product'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}
