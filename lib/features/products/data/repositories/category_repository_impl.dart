import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/category.dart' as domain;
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase database;

  final String businessId;

  CategoryRepositoryImpl(this.database, this.businessId);

  @override
  Future<List<domain.Category>> getCategories({bool activeOnly = true}) async {
    final query = database.select(database.categories);

    query.where((category) => category.businessId.equals(businessId));

    if (activeOnly) {
      query.where((category) => category.isActive.equals(true));
    }

    query.orderBy([(category) => OrderingTerm.asc(category.name)]);

    final rows = await query.get();

    return rows
        .map(
          (row) => domain.Category(
            id: row.id,
            name: row.name,
            description: row.description,
            isActive: row.isActive,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
          ),
        )
        .toList();
  }

  @override
  Future<domain.Category?> getCategoryById(String id) async {
    final query = database.select(database.categories)
      ..where((category) => category.id.equals(id))
      ..where((category) => category.businessId.equals(businessId));

    final row = await query.getSingleOrNull();

    if (row == null) return null;

    return domain.Category(
      id: row.id,
      name: row.name,
      description: row.description,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  @override
  Future<void> saveCategory(domain.Category category) async {
    await database
        .into(database.categories)
        .insertOnConflictUpdate(
          CategoriesCompanion(
            businessId: Value(businessId),
            id: Value(category.id),
            name: Value(category.name),
            description: Value(category.description),
            isActive: Value(category.isActive),
            createdAt: Value(category.createdAt),
            updatedAt: Value(category.updatedAt),
          ),
        );
  }

  @override
  Future<void> archiveCategory(String id) async {
    await (database.update(database.categories)
          ..where((category) => category.id.equals(id))
          ..where((category) => category.businessId.equals(businessId)))
        .write(
          CategoriesCompanion(
            isActive: const Value(false),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }
}
