import 'package:uuid/uuid.dart';

import '../entities/product_barcode.dart';
import '../repositories/barcode_repository.dart';

class BarcodeManagementService {
  final BarcodeRepository repository;
  final Uuid uuid;

  BarcodeManagementService({required this.repository, Uuid? uuid})
    : uuid = uuid ?? const Uuid();

  Future<void> addBarcode({
    required String productId,
    required String barcode,
  }) async {
    final normalizedBarcode = barcode.trim();

    if (normalizedBarcode.isEmpty) {
      throw ArgumentError('Barcode is required.');
    }

    if (normalizedBarcode.length > 128) {
      throw ArgumentError('Barcode cannot exceed 128 characters.');
    }

    await repository.addBarcode(
      ProductBarcode(
        id: uuid.v4(),
        productId: productId,
        barcode: normalizedBarcode,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> deleteBarcode(String barcodeId) {
    return repository.deleteBarcode(barcodeId);
  }
}
