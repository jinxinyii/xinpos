import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../shared/widgets/app_notification.dart';

import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/barcode_providers.dart';
import '../../../products/presentation/providers/products_list_provider.dart';
import '../../../sales/domain/entities/sale_checkout_item.dart';
import '../../../sales/domain/entities/sale_checkout_result.dart';
import '../../../sales/presentation/providers/sale_providers.dart';
import '../../../settings/data/services/bluetooth_printer_service.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchController = TextEditingController();
  final Map<String, _CartLine> _cart = {};

  String _search = '';
  bool _isScanning = false;
  bool _isCheckingOut = false;
  bool _isPrintingReceipt = false;

  int get _cartQuantity =>
      _cart.values.fold<int>(0, (total, line) => total + line.quantity);

  int get _cartTotal => _cart.values.fold<int>(
    0,
    (total, line) => total + line.product.sellingPriceCentavos * line.quantity,
  );

  String _formatPrice(int centavos) {
    return NumberFormat.currency(
      locale: 'en_PH',
      symbol: '₱',
      decimalDigits: 2,
    ).format(centavos / 100);
  }

  void _addProduct(Product product) {
    setState(() {
      final existing = _cart[product.id];

      if (existing == null) {
        _cart[product.id] = _CartLine(product: product);
      } else {
        existing.quantity++;
      }
    });

    final quantity = _cart[product.id]?.quantity ?? 1;
    AppNotification.show(
      context,
      message: '$quantity × ${product.name} added to cart.',
    );
  }

  void _increaseQuantity(String productId) {
    setState(() {
      final line = _cart[productId];
      if (line != null) line.quantity++;
    });
  }

  void _decreaseQuantity(String productId) {
    setState(() {
      final line = _cart[productId];

      if (line == null) return;

      if (line.quantity <= 1) {
        _cart.remove(productId);
      } else {
        line.quantity--;
      }
    });
  }

  Future<void> _scanBarcode() async {
    if (_isScanning) return;

    setState(() => _isScanning = true);

    try {
      final barcode = await GoRouter.of(context).push<String>('/scanner');

      if (!mounted || barcode == null || barcode.trim().isEmpty) return;

      final product = await ref.read(
        productByBarcodeProvider(barcode.trim()).future,
      );

      if (!mounted) return;

      if (product == null) {
        AppNotification.show(
          context,
          message: 'No product found for barcode: $barcode',
          type: AppNotificationType.error,
        );
        return;
      }

      _addProduct(product);
    } catch (error) {
      if (!mounted) return;

      AppNotification.show(
        context,
        message: 'Unable to look up barcode: $error',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _clearCart() {
    setState(() => _cart.clear());
  }

  Future<void> _checkout() async {
    if (_cart.isEmpty || _isCheckingOut) return;

    final payment = await showDialog<_CheckoutPayment>(
      context: context,
      builder: (_) => _CheckoutDialog(totalCentavos: _cartTotal),
    );

    if (!mounted || payment == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Sale'),
        content: Text(
          'Complete this sale for ${_formatPrice(_cartTotal)} '
          'using ${payment.method.toUpperCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm Sale'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isCheckingOut = true);

    try {
      final result = await ref
          .read(saleCheckoutServiceProvider)
          .checkout(
            items: _cart.values
                .map(
                  (line) => SaleCheckoutItem(
                    productId: line.product.id,
                    quantity: line.quantity,
                  ),
                )
                .toList(),
            paymentMethod: payment.method,
            amountTenderedCentavos: payment.amountTenderedCentavos,
            referenceNumber: payment.referenceNumber,
          );

      if (!mounted) return;

      setState(() {
        _cart.clear();
        _isCheckingOut = false;
      });

      ref.invalidate(productsListProvider);

      await _showSaleSuccess(result);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isCheckingOut = false);

      AppNotification.show(
        context,
        message: 'Checkout failed: $error',
        type: AppNotificationType.error,
      );
    }
  }

  Future<void> _printCheckoutReceipt(SaleCheckoutResult result) async {
    if (_isPrintingReceipt) return;
    setState(() => _isPrintingReceipt = true);

    try {
      final sale = await ref
          .read(saleRepositoryProvider)
          .getSaleDetails(result.saleId);

      if (!mounted) return;

      if (sale == null) {
        AppNotification.show(
          context,
          message:
              'Sale was saved, but its receipt details could not be loaded.',
          type: AppNotificationType.error,
        );
        return;
      }

      final printed = await BluetoothPrinterService().printSaleReceipt(sale);
      if (!mounted) return;

      AppNotification.show(
        context,
        message: printed
            ? 'Receipt sent to printer'
            : 'Unable to print receipt',
        type: printed ? AppNotificationType.success : AppNotificationType.error,
      );
    } catch (error) {
      if (!mounted) return;
      AppNotification.show(
        context,
        message: 'Print failed: $error',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isPrintingReceipt = false);
    }
  }

  Future<void> _showSaleSuccess(SaleCheckoutResult result) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.check_circle_outline,
          size: 56,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: const Text('Sale Completed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Your transaction was saved successfully.'),
            const SizedBox(height: 16),
            const Text('Queue Number'),
            const SizedBox(height: 4),
            Text(
              result.queueCode,
              style: Theme.of(dialogContext).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Receipt Number'),
            const SizedBox(height: 4),
            SelectableText(
              result.receiptNumber,
              style: Theme.of(dialogContext).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _ReceiptAmountRow(
              label: 'Total',
              value: _formatPrice(result.totalCentavos),
            ),
            _ReceiptAmountRow(
              label: 'Change',
              value: _formatPrice(result.changeCentavos),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _isPrintingReceipt
                ? null
                : () {
                    Navigator.pop(dialogContext);
                    _printCheckoutReceipt(result);
                  },
            icon: const Icon(Icons.print_rounded),
            label: const Text('Print Receipt'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(
      productsListProvider((search: _search, categoryId: null)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Point of Sale'),
        actions: [
          IconButton(
            tooltip: 'Scan Barcode',
            onPressed: _isScanning || _isCheckingOut ? null : _scanBarcode,
            icon: _isScanning
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_scanner),
          ),
          if (_cart.isNotEmpty)
            IconButton(
              tooltip: 'Clear Cart',
              onPressed: _isCheckingOut ? null : _clearCart,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 760) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: _buildProductsSection(context, products),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: constraints.maxWidth * 0.34,
                    child: _buildCartPanel(context, expanded: true),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(child: _buildProductsSection(context, products)),
              if (_cart.isNotEmpty) _buildMobileCartBar(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProductsSection(
    BuildContext context,
    AsyncValue<List<Product>> products,
  ) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search product name or SKU',
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
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Products',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '$_cartQuantity item${_cartQuantity == 1 ? '' : 's'} in cart',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: products.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 12),
                  const Text('Unable to load products.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      ref.invalidate(
                        productsListProvider((
                          search: _search,
                          categoryId: null,
                        )),
                      );
                    },
                    child: const Text('Try Again'),
                  ),
                ],
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
                        const Icon(Icons.inventory_2_outlined, size: 56),
                        const SizedBox(height: 12),
                        Text(
                          _search.isEmpty
                              ? 'No products available'
                              : 'No matching products',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add products in the Products section first.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 560) {
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 390,
                            mainAxisExtent: 154,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, index) =>
                          _buildProductCard(context, items[index]),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: items.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _buildProductCard(context, items[index]),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final cartLine = _cart[product.id];

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.8)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                product.trackInventory
                    ? Icons.inventory_2_outlined
                    : Icons.shopping_bag_outlined,
                color: colors.onSecondaryContainer,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatPrice(product.sellingPriceCentavos),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (cartLine != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      '${cartLine.quantity} in cart',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else if (product.sku != null && product.sku!.isNotEmpty)
                    Text(
                      'SKU: ${product.sku}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _isCheckingOut ? null : () => _addProduct(product),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 42),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileCartBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: InkWell(
            onTap: _showMobileCart,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: colors.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_cartQuantity item${_cartQuantity == 1 ? '' : 's'} in cart',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colors.onPrimaryContainer),
                        ),
                        Text(
                          _formatPrice(_cartTotal),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'View cart',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: colors.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMobileCart() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, refreshSheet) {
            final theme = Theme.of(sheetContext);
            final colors = theme.colorScheme;

            return FractionallySizedBox(
              heightFactor: 0.82,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Cart',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$_cartQuantity item${_cartQuantity == 1 ? '' : 's'}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isCheckingOut
                              ? null
                              : () {
                                  _clearCart();
                                  refreshSheet(() {});
                                },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _cart.isEmpty
                          ? Center(
                              child: Text(
                                'Your cart is empty',
                                style: theme.textTheme.bodyLarge,
                              ),
                            )
                          : ListView.separated(
                              itemCount: _cart.length,
                              separatorBuilder: (_, index) =>
                                  const Divider(height: 18),
                              itemBuilder: (context, index) {
                                final line = _cart.values.elementAt(index);
                                return Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            line.product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          Text(
                                            _formatPrice(
                                              line
                                                      .product
                                                      .sellingPriceCentavos *
                                                  line.quantity,
                                            ),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _isCheckingOut
                                          ? null
                                          : () {
                                              _decreaseQuantity(
                                                line.product.id,
                                              );
                                              refreshSheet(() {});
                                            },
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 24,
                                      child: Text(
                                        '${line.quantity}',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _isCheckingOut
                                          ? null
                                          : () {
                                              _increaseQuantity(
                                                line.product.id,
                                              );
                                              refreshSheet(() {});
                                            },
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total',
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        Text(
                          _formatPrice(_cartTotal),
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _cart.isEmpty || _isCheckingOut
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _checkout();
                              },
                        icon: const Icon(Icons.point_of_sale_rounded),
                        label: const Text('Proceed to Checkout'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartPanel(BuildContext context, {bool expanded = false}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Cart',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$_cartQuantity item${_cartQuantity == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_cart.isNotEmpty)
                    TextButton(
                      onPressed: _isCheckingOut ? null : _clearCart,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (_cart.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 42,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your cart is empty',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          'Add products to start a sale.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                if (expanded)
                  Expanded(child: _buildCartItems(context))
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 132),
                    child: _buildCartItems(context),
                  ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Text('Total', style: theme.textTheme.titleMedium),
                    ),
                    Text(
                      _formatPrice(_cartTotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isCheckingOut ? null : _checkout,
                    icon: _isCheckingOut
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.point_of_sale),
                    label: Text(
                      _isCheckingOut
                          ? 'Processing Sale...'
                          : 'Proceed to Checkout',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartItems(BuildContext context) {
    final theme = Theme.of(context);

    return ListView.separated(
      shrinkWrap: true,
      itemCount: _cart.length,
      separatorBuilder: (_, index) => const Divider(height: 12),
      itemBuilder: (context, index) {
        final line = _cart.values.elementAt(index);

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _formatPrice(
                      line.product.sellingPriceCentavos * line.quantity,
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Decrease Quantity',
              visualDensity: VisualDensity.compact,
              onPressed: _isCheckingOut
                  ? null
                  : () => _decreaseQuantity(line.product.id),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 24,
              child: Text('${line.quantity}', textAlign: TextAlign.center),
            ),
            IconButton(
              tooltip: 'Increase Quantity',
              visualDensity: VisualDensity.compact,
              onPressed: _isCheckingOut
                  ? null
                  : () => _increaseQuantity(line.product.id),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        );
      },
    );
  }
}

class _CartLine {
  final Product product;
  int quantity;

  _CartLine({required this.product}) : quantity = 1;
}

class _CheckoutPayment {
  final String method;
  final int amountTenderedCentavos;
  final String? referenceNumber;

  const _CheckoutPayment({
    required this.method,
    required this.amountTenderedCentavos,
    this.referenceNumber,
  });
}

class _CheckoutDialog extends StatefulWidget {
  final int totalCentavos;

  const _CheckoutDialog({required this.totalCentavos});

  @override
  State<_CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<_CheckoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _cashController;
  final _referenceController = TextEditingController();

  String _method = 'cash';

  int? _parseAmount(String value) {
    final normalized = value.trim();

    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalized)) {
      return null;
    }

    final parts = normalized.split('.');
    final pesos = int.tryParse(parts[0]);

    if (pesos == null) return null;

    final centavos = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));

    return pesos * 100 + centavos;
  }

  @override
  void initState() {
    super.initState();
    _cashController = TextEditingController(
      text: (widget.totalCentavos / 100).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _cashController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = _method == 'cash'
        ? _parseAmount(_cashController.text)!
        : widget.totalCentavos;

    Navigator.pop(
      context,
      _CheckoutPayment(
        method: _method,
        amountTenderedCentavos: amount,
        referenceNumber: _method == 'gcash'
            ? _referenceController.text.trim()
            : null,
      ),
    );
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
    final change = _method == 'cash'
        ? (_parseAmount(_cashController.text) ?? 0) - widget.totalCentavos
        : 0;

    return AlertDialog(
      title: const Text('Checkout'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Amount',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _formatPrice(widget.totalCentavos),
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                'Payment Method',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              RadioGroup<String>(
                groupValue: _method,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _method = value);
                  }
                },
                child: Column(
                  children: [
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'cash',
                      title: const Text('Cash'),
                      secondary: const Icon(Icons.payments_outlined),
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'gcash',
                      title: const Text('GCash'),
                      secondary: const Icon(
                        Icons.account_balance_wallet_outlined,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_method == 'cash') ...[
                TextFormField(
                  controller: _cashController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cash Received',
                    prefixText: '₱ ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) {
                    final amount = _parseAmount(value ?? '');

                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount.';
                    }

                    if (amount < widget.totalCentavos) {
                      return 'Cash received is insufficient.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: Text('Change')),
                    Text(
                      _formatPrice(change < 0 ? 0 : change),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
              if (_method == 'gcash')
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'GCash Reference Number',
                    hintText: 'Enter transaction reference',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_method == 'gcash' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'GCash reference number is required.';
                    }

                    return null;
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }
}

class _ReceiptAmountRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptAmountRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
