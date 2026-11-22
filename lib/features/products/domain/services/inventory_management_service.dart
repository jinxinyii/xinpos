import 'package:uuid/uuid.dart';

import '../entities/inventory_movement.dart';
import '../repositories/inventory_repository.dart';
import '../repositories/product_repository.dart';

class InventoryManagementService {
  final InventoryRepository inventoryRepository;
  final ProductRepository productRepository;
  final Uuid uuid;

  InventoryManagementService({
    required this.inventoryRepository,
    required this.productRepository,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  Future<void> stockIn({
    required String productId,
    required int quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Stock-in quantity must be greater than zero.');
    }

    await _recordMovement(
      productId: productId,
      movementType: 'stock_in',
      quantityDelta: quantity,
      note: note,
    );
  }

  Future<void> stockOut({
    required String productId,
    required int quantity,
    String? note,
  }) async {
    if (quantity <= 0) {
      throw ArgumentError('Stock-out quantity must be greater than zero.');
    }

    await _recordMovement(
      productId: productId,
      movementType: 'stock_out',
      quantityDelta: -quantity,
      note: note,
    );
  }

  Future<void> adjustStock({
    required String productId,
    required int countedQuantity,
    String? note,
  }) async {
    if (countedQuantity < 0) {
      throw ArgumentError('Counted stock cannot be negative.');
    }

    final product = await productRepository.getProductById(productId);

    if (product == null || !product.isActive) {
      throw StateError('Active product could not be found.');
    }

    if (!product.trackInventory) {
      throw StateError('Inventory tracking is disabled for this product.');
    }

    final currentStock = await inventoryRepository.getStockQuantity(productId);
    final difference = countedQuantity - currentStock;

    if (difference == 0) {
      throw StateError('The counted stock matches the current stock.');
    }

    await inventoryRepository.recordMovement(
      InventoryMovement(
        id: uuid.v4(),
        productId: product.id,
        productNameSnapshot: product.name,
        movementType: 'stock_adjustment',
        quantityDelta: difference,
        referenceType: 'manual_adjustment',
        referenceId: null,
        note: _normalizeNote(note),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _recordMovement({
    required String productId,
    required String movementType,
    required int quantityDelta,
    String? note,
  }) async {
    final product = await productRepository.getProductById(productId);

    if (product == null || !product.isActive) {
      throw StateError('Active product could not be found.');
    }

    if (!product.trackInventory) {
      throw StateError('Inventory tracking is disabled for this product.');
    }

    await inventoryRepository.recordMovement(
      InventoryMovement(
        id: uuid.v4(),
        productId: product.id,
        productNameSnapshot: product.name,
        movementType: movementType,
        quantityDelta: quantityDelta,
        referenceType: 'manual',
        referenceId: null,
        note: _normalizeNote(note),
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  String? _normalizeNote(String? note) {
    final normalized = note?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
