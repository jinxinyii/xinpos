import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../entities/category.dart' as domain;
import '../repositories/category_repository.dart';

class CategoryManagementService {
  final AppDatabase database;
  final CategoryRepository repository;
  final Uuid uuid;

  CategoryManagementService({
    required this.database,
    required this.repository,
    Uuid? uuid,
  }) : uuid = uuid ?? const Uuid();

  Future<void> saveCategory({
    String? id,
    required String name,
    String? description,
  }) async {
    final normalizedName = name.trim();
    final normalizedDescription = description?.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Category name is required.');
    }

    if (normalizedName.length > 100) {
      throw ArgumentError('Category name cannot exceed 100 characters.');
    }

    final existingCategories = await repository.getCategories(
      activeOnly: false,
    );

    final duplicate = existingCategories.any(
      (category) =>
          category.id != id &&
          category.isActive &&
          category.name.toLowerCase() == normalizedName.toLowerCase(),
    );

    if (duplicate) {
      throw StateError('A category with this name already exists.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = id == null ? null : await repository.getCategoryById(id);

    if (id != null && existing == null) {
      throw StateError('Category not found.');
    }

    if (existing != null && !existing.isActive) {
      throw StateError('Archived categories cannot be edited.');
    }

    await repository.saveCategory(
      domain.Category(
        id: id ?? uuid.v4(),
        name: normalizedName,
        description:
            normalizedDescription == null || normalizedDescription.isEmpty
            ? null
            : normalizedDescription,
        isActive: true,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Future<void> archiveCategory(String id) async {
    final category = await repository.getCategoryById(id);

    if (category == null || !category.isActive) {
      throw StateError('Active category not found.');
    }

    final productsUsingCategory = await (database.select(
      database.products,
    )..where((product) => product.categoryId.equals(id))).get();

    if (productsUsingCategory.isNotEmpty) {
      throw StateError(
        'This category is assigned to existing products. '
        'Reassign those products before archiving it.',
      );
    }

    await repository.archiveCategory(id);
  }
}
