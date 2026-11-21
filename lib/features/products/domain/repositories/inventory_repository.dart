import '../entities/inventory_movement.dart';

abstract class InventoryRepository {
  Future<int> getStockQuantity(String productId);

  Future<List<InventoryMovement>> getMovements(String productId);

  Future<void> recordMovement(InventoryMovement movement);
}
