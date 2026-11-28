import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/category.dart';
import '../providers/product_providers.dart';
import '../providers/product_creation_provider.dart';
import '../providers/product_form_state.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costController = TextEditingController();
  final _sellingController = TextEditingController();
  final _reorderController = TextEditingController(text: '0');
  final _stockController = TextEditingController(text: '0');

  Future<List<Category>>? _categoriesFuture;
  String? _categoryId;
  bool _trackInventory = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = ref.read(categoryRepositoryProvider).getCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _descriptionController.dispose();
    _costController.dispose();
    _sellingController.dispose();
    _reorderController.dispose();
    _stockController.dispose();
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

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final form = ProductFormState(
        name: _nameController.text,
        sku: _skuController.text,
        description: _descriptionController.text,
        categoryId: _categoryId,
        costPrice: _costController.text,
        sellingPrice: _sellingController.text,
        reorderLevel: _reorderController.text,
        initialStock: _stockController.text,
        trackInventory: _trackInventory,
      );

      final productId = await ref
          .read(productCreationServiceProvider)
          .createProduct(
            name: form.name,
            sku: form.sku,
            description: form.description,
            categoryId: form.categoryId,
            costPriceCentavos: form.parseMoneyToCentavos(form.costPrice),
            sellingPriceCentavos: form.parseMoneyToCentavos(form.sellingPrice),
            reorderLevel: form.parseQuantity(form.reorderLevel),
            trackInventory: form.trackInventory,
            initialStock: form.parseQuantity(form.initialStock),
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(
          context: context,
          content: Text('Product saved successfully.'),
        ),
      );

      Navigator.of(context).pop(productId);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        AppSnackBar(context: context, content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: SafeArea(
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
              FutureBuilder<List<Category>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text('Unable to load categories: ${snapshot.error}');
                  }

                  final categories = snapshot.data ?? [];

                  return DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: _decoration('Category'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('No Category'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _categoryId = value);
                    },
                  );
                },
              ),
              _sectionTitle('Pricing'),
              TextFormField(
                controller: _costController,
                decoration: _decoration(
                  'Cost Price',
                  hint: '0.00',
                ).copyWith(prefixText: '₱ '),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _validatePrice,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _sellingController,
                decoration: _decoration(
                  'Selling Price',
                  hint: '0.00',
                ).copyWith(prefixText: '₱ '),
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
                  setState(() {
                    _trackInventory = value;
                    if (!value) {
                      _stockController.text = '0';
                      _reorderController.text = '0';
                    }
                  });
                },
              ),
              if (_trackInventory) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stockController,
                  decoration: _decoration('Initial Stock'),
                  keyboardType: TextInputType.number,
                  validator: _validateQuantity,
                ),
                const SizedBox(height: 14),
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
                      : const Text('Save Product'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
