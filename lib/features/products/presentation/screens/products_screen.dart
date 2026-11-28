import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/category_providers.dart';
import '../providers/inventory_providers.dart';
import '../providers/products_list_provider.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();

  String _search = '';
  String? _categoryId;

  ProductFilter get _filter => (search: _search, categoryId: _categoryId);

  String _formatPrice(int centavos) {
    return NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(centavos / 100);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshProducts() async {
    ref.invalidate(productsListProvider);
    ref.invalidate(stockQuantityProvider);
    await ref.read(productsListProvider(_filter).future);
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsListProvider(_filter));
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            onPressed: () async {
              await context.push('/products/categories');
              ref.invalidate(categoriesProvider);
              ref.invalidate(productsListProvider);
            },
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage Categories',
          ),
          IconButton(
            onPressed: _refreshProducts,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/products/add');
          ref.invalidate(productsListProvider);
          ref.invalidate(stockQuantityProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _search = value.trim());
              },
              decoration: InputDecoration(
                hintText: 'Search product or SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: categories.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) => const SizedBox.shrink(),
              data: (items) => DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: 'Filter by Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All Categories'),
                  ),
                  ...items.map(
                    (category) => DropdownMenuItem<String>(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _categoryId = value);
                },
              ),
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      const Text('Unable to load products.'),
                      const SizedBox(height: 8),
                      Text(error.toString(), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(productsListProvider),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _search.isNotEmpty || _categoryId != null
                                ? 'No matching products'
                                : 'No products yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _search.isNotEmpty || _categoryId != null
                                ? 'Try changing your search or category filter.'
                                : 'Add your first product to start managing inventory.',
                            textAlign: TextAlign.center,
                          ),
                          if (_search.isNotEmpty || _categoryId != null)
                            TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _search = '';
                                  _categoryId = null;
                                });
                              },
                              child: const Text('Clear Filters'),
                            ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshProducts,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final product = items[index];

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          onTap: () async {
                            await context.push('/products/${product.id}');
                            ref.invalidate(productsListProvider);
                            ref.invalidate(stockQuantityProvider(product.id));
                          },
                          leading: CircleAvatar(
                            child: Icon(
                              product.trackInventory
                                  ? Icons.inventory_2_outlined
                                  : Icons.shopping_bag_outlined,
                            ),
                          ),
                          title: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.sku != null &&
                                  product.sku!.isNotEmpty)
                                Text('SKU: ${product.sku}'),
                              const SizedBox(height: 4),
                              Text(
                                _formatPrice(product.sellingPriceCentavos),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (product.trackInventory)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final stock = ref.watch(
                                      stockQuantityProvider(product.id),
                                    );

                                    return stock.when(
                                      loading: () => const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: LinearProgressIndicator(),
                                      ),
                                      error: (error, stackTrace) =>
                                          const Text('Stock unavailable'),
                                      data: (quantity) {
                                        final isLow =
                                            quantity <= product.reorderLevel;

                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 6,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                isLow
                                                    ? Icons
                                                          .warning_amber_rounded
                                                    : Icons
                                                          .check_circle_outline,
                                                size: 16,
                                                color: isLow
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .error
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .primary,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Stock: $quantity',
                                                style: TextStyle(
                                                  color: isLow
                                                      ? Theme.of(context)
                                                            .colorScheme
                                                            .error
                                                      : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (isLow) ...[
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Low stock',
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .error,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              if (!product.trackInventory)
                                const Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text('Inventory not tracked'),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
