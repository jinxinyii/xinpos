class Product {
  final String id;
  final String? categoryId;
  final String name;
  final String? sku;
  final String? description;
  final int costPriceCentavos;
  final int sellingPriceCentavos;
  final int reorderLevel;
  final bool trackInventory;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    this.sku,
    this.description,
    required this.costPriceCentavos,
    required this.sellingPriceCentavos,
    required this.reorderLevel,
    required this.trackInventory,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}
