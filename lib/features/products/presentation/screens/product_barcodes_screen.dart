import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';

import '../providers/barcode_providers.dart';
import '../providers/product_details_provider.dart';

class ProductBarcodesScreen extends ConsumerWidget {
  final String productId;

  const ProductBarcodesScreen({required this.productId, super.key});

  Future<void> _addBarcode(
    BuildContext context,
    WidgetRef ref, {
    String? initialBarcode,
  }) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _BarcodeDialog(initialBarcode: initialBarcode),
    );

    if (result == null || !context.mounted) return;

    try {
      await ref
          .read(barcodeManagementServiceProvider)
          .addBarcode(productId: productId, barcode: result);

      ref.invalidate(productBarcodesProvider(productId));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Barcode added successfully.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Unable to add barcode: $error'),
        ),
      );
    }
  }

  Future<void> _scanBarcode(BuildContext context, WidgetRef ref) async {
    final barcode = await GoRouter.of(context).push<String>('/scanner');

    if (barcode == null || !context.mounted) return;

    await _addBarcode(context, ref, initialBarcode: barcode);
  }

  Future<void> _deleteBarcode(
    BuildContext context,
    WidgetRef ref,
    String barcodeId,
    String barcode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Barcode?'),
        content: Text('Remove barcode "$barcode" from this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(barcodeManagementServiceProvider).deleteBarcode(barcodeId);

      ref.invalidate(productBarcodesProvider(productId));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Barcode removed successfully.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Unable to remove barcode: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(productDetailsProvider(productId));
    final barcodesState = ref.watch(productBarcodesProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Barcodes'),
        actions: [
          IconButton(
            tooltip: 'Scan Barcode',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scanBarcode(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addBarcode(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Barcode'),
      ),
      body: productState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load product: $error')),
        data: (product) {
          if (product == null || !product.isActive) {
            return const Center(child: Text('Product not found.'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.inventory_2_outlined),
                    ),
                    title: Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      product.sku == null || product.sku!.isEmpty
                          ? 'No SKU assigned'
                          : 'SKU: ${product.sku}',
                    ),
                  ),
                ),
              ),
              Expanded(
                child: barcodesState.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48),
                          const SizedBox(height: 12),
                          const Text('Unable to load barcodes.'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              ref.invalidate(
                                productBarcodesProvider(productId),
                              );
                            },
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (barcodes) {
                    if (barcodes.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_2,
                                size: 64,
                                color: Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No barcodes yet',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Add a barcode to make this product easier '
                                'to identify during checkout.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: barcodes.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final barcode = barcodes[index];

                        return Card(
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.qr_code_2),
                            ),
                            title: Text(
                              barcode.barcode,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Added ${DateTime.fromMillisecondsSinceEpoch(barcode.createdAt).toLocal()}'
                                  .split('.')
                                  .first,
                            ),
                            trailing: IconButton(
                              tooltip: 'Remove Barcode',
                              onPressed: () => _deleteBarcode(
                                context,
                                ref,
                                barcode.id,
                                barcode.barcode,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BarcodeDialog extends StatefulWidget {
  final String? initialBarcode;

  const _BarcodeDialog({this.initialBarcode});

  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcodeController;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
      text: widget.initialBarcode ?? '',
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(context, _barcodeController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Barcode'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _barcodeController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Barcode',
            hintText: 'Enter or scan a barcode',
            prefixIcon: Icon(Icons.qr_code_2),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final barcode = value?.trim() ?? '';

            if (barcode.isEmpty) {
              return 'Barcode is required.';
            }

            if (barcode.length > 128) {
              return 'Barcode cannot exceed 128 characters.';
            }

            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save Barcode')),
      ],
    );
  }
}
