class ProductFormState {
  final String name;
  final String sku;
  final String description;
  final String? categoryId;
  final String costPrice;
  final String sellingPrice;
  final String reorderLevel;
  final String initialStock;
  final bool trackInventory;

  const ProductFormState({
    this.name = '',
    this.sku = '',
    this.description = '',
    this.categoryId,
    this.costPrice = '',
    this.sellingPrice = '',
    this.reorderLevel = '0',
    this.initialStock = '0',
    this.trackInventory = true,
  });

  int parseMoneyToCentavos(String value) {
    final normalized = value.trim();
    final pattern = RegExp(r'^\d+(\.\d{1,2})?$');

    if (!pattern.hasMatch(normalized)) {
      throw const FormatException(
        'Enter a valid price with up to two decimal places.',
      );
    }

    final parts = normalized.split('.');
    final pesos = int.parse(parts[0]);
    final centavos = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));

    return pesos * 100 + centavos;
  }

  int parseQuantity(String value) {
    final quantity = int.tryParse(value.trim());

    if (quantity == null || quantity < 0) {
      throw const FormatException('Enter a valid whole-number quantity.');
    }

    return quantity;
  }
}
