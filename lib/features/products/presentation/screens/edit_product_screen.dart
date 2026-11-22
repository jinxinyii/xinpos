import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../providers/category_providers.dart';
import '../providers/product_details_provider.dart';
import '../providers/product_management_provider.dart';
import '../providers/product_form_state.dart';
import '../providers/products_list_provider.dart';

class EditProductScreen extends ConsumerWidget {
  final String productId;

  const EditProductScreen({required this.productId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productState = ref.watch(productDetailsProvider(productId));
    final categoriesState = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Product')),
      body: productState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Unable to load product: $error'),
          ),
        ),
        data: (product) {
          if (product == null || !product.isActive) {
            return const Center(child: Text('Product not found.'));
          }

          return categoriesState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Unable to load categories: $error')),
            data: (categories) =>
                _EditProductForm(product: product, categories: categories),
          );
        },
      ),
    );
  }
}

class _EditProductForm extends ConsumerStatefulWidget {
  final Product product;
  final List<Category> categories;

  const _EditProductForm({required this.product, required this.categories});

  @override
  ConsumerState<_EditProductForm> createState() => _EditProductFormState();
}

class _EditProductFormState extends ConsumerState<_EditProductForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _costController;
  late final TextEditingController _sellingController;
  late final TextEditingController _reorderController;

  String? _categoryId;
  late bool _trackInventory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController = TextEditingController(text: product.name);
    _skuController = TextEditingController(text: product.sku ?? '');
    _descriptionController = TextEditingController(
      text: product.description ?? '',
    );
    _costController = TextEditingController(
      text: (product.costPriceCentavos / 100).toStringAsFixed(2),
    );
    _sellingController = TextEditingController(
      text: (product.sellingPriceCentavos / 100).toStringAsFixed(2),
    );
    _reorderController = TextEditingController(
      text: product.reorderLevel.toString(),
    );

    _categoryId =
        widget.categories.any((category) => category.id == product.categoryId)
        ? product.categoryId
        : null;

    _trackInventory = product.trackInventory;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    try {
      const ProductFormState().parseMoneyToCentavos(value);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  String? _validateQuantity(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    try {
      const ProductFormState().parseQuantity(value);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      const parser = ProductFormState();

      await ref
          .read(productManagementServiceProvider)
          .updateProduct(
            productId: widget.product.id,
            name: _nameController.text,
            sku: _skuController.text,
            description: _descriptionController.text,
            categoryId: _categoryId,
            costPriceCentavos: parser.parseMoneyToCentavos(
              _costController.text,
            ),
            sellingPriceCentavos: parser.parseMoneyToCentavos(
              _sellingController.text,
            ),
            reorderLevel: _trackInventory
                ? parser.parseQuantity(_reorderController.text)
                : 0,
            trackInventory: _trackInventory,
          );

      ref.invalidate(productDetailsProvider(widget.product.id));
      ref.invalidate(productsListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully.')),
      );

      context.pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Product Information'),
            TextFormField(
              controller: _nameController,
              decoration: _decoration('Product Name'),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Product name is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _skuController,
              decoration: _decoration('SKU', hint: 'Optional product code'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              decoration: _decoration('Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: _decoration('Category'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('No category'),
                ),
                ...widget.categories.map(
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
            _sectionTitle('Pricing'),
            TextFormField(
              controller: _costController,
              decoration: _decoration('Cost Price').copyWith(prefixText: '₱ '),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validatePrice,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _sellingController,
              decoration: _decoration('Selling Price')
                  .copyWith(prefixText: '₱ '),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validatePrice,
            ),
            _sectionTitle('Inventory'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Track Inventory'),
              subtitle: const Text('Monitor stock levels for this product.'),
              value: _trackInventory,
              onChanged: (value) {
                setState(() => _trackInventory = value);
              },
            ),
            if (_trackInventory) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _reorderController,
                decoration: _decoration('Low Stock Alert Level'),
                keyboardType: TextInputType.number,
                validator: _validateQuantity,
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _isSaving ? null : _saveProduct,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
