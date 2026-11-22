import '../entities/product.dart';
import '../entities/product_barcode.dart';

abstract class BarcodeRepository {
  Future<List<ProductBarcode>> getBarcodes(String productId);

  Future<Product?> getProductByBarcode(String barcode);

  Future<void> addBarcode(ProductBarcode barcode);

  Future<void> deleteBarcode(String barcodeId);
}
