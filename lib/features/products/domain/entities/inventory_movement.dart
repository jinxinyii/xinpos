class InventoryMovement {
  final String id;
  final String productId;
  final String productNameSnapshot;
  final String movementType;
  final int quantityDelta;
  final String? referenceType;
  final String? referenceId;
  final String? note;
  final int createdAt;

  const InventoryMovement({
    required this.id,
    required this.productId,
    required this.productNameSnapshot,
    required this.movementType,
    required this.quantityDelta,
    this.referenceType,
    this.referenceId,
    this.note,
    required this.createdAt,
  });
}
