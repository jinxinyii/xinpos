import '../entities/category.dart';

abstract class CategoryRepository {
  Future<List<Category>> getCategories({bool activeOnly = true});

  Future<Category?> getCategoryById(String id);

  Future<void> saveCategory(Category category);

  Future<void> archiveCategory(String id);
}
