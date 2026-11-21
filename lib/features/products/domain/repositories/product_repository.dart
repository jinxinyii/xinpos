import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getProducts({
    String? search,
    String? categoryId,
    bool activeOnly = true,
  });

  Future<Product?> getProductById(String id);

  Future<void> saveProduct(Product product);

  Future<void> archiveProduct(String id);
}
