import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';
import '../../domain/entities/business_dataset_summary.dart';

class BusinessDatasetRepository {
  BusinessDatasetRepository(this.database);

  final AppDatabase database;
  static const _uuid = Uuid();

  Stream<List<BusinessDatasetSummary>> watchAll() {
    return (database.select(database.businessDatasets)..orderBy([
          (dataset) => OrderingTerm.asc(dataset.isArchived),
          (dataset) => OrderingTerm.asc(dataset.name),
        ]))
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => BusinessDatasetSummary(
                  id: row.id,
                  name: row.name,
                  isArchived: row.isArchived,
                  createdAt: row.createdAt,
                  updatedAt: row.updatedAt,
                ),
              )
              .toList(),
        );
  }

  Future<void> create(String name) async {
    final value = name.trim();
    if (value.isEmpty || value.length > 80) {
      throw ArgumentError('Enter a business name between 1 and 80 characters.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await database
        .into(database.businessDatasets)
        .insert(
          BusinessDatasetsCompanion.insert(
            id: _uuid.v4(),
            name: value,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> rename(String id, String name) async {
    if (id == 'default') {
      throw StateError('The default business cannot be renamed.');
    }
    final value = name.trim();
    if (value.isEmpty || value.length > 80) {
      throw ArgumentError('Enter a business name between 1 and 80 characters.');
    }
    final count =
        await (database.update(database.businessDatasets)
              ..where((row) => row.id.equals(id))
              ..where((row) => row.isArchived.equals(false)))
            .write(
              BusinessDatasetsCompanion(
                name: Value(value),
                updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
              ),
            );
    if (count == 0) throw StateError('Active business could not be found.');
  }

  Future<void> setArchived(String id, bool archived) async {
    if (id == 'default' && archived) {
      throw StateError('The default business cannot be archived.');
    }
    final count =
        await (database.update(
          database.businessDatasets,
        )..where((row) => row.id.equals(id))).write(
          BusinessDatasetsCompanion(
            isArchived: Value(archived),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
    if (count == 0) throw StateError('Business could not be found.');
  }

  Future<void> deleteBusiness(String id) async {
    if (id == 'default') {
      throw StateError('The default business cannot be deleted.');
    }

    await database.transaction(() async {
      final business = await (database.select(
        database.businessDatasets,
      )..where((row) => row.id.equals(id))).getSingleOrNull();

      if (business == null) {
        throw StateError('Business could not be found.');
      }

      await database.customStatement(
        '''
        DELETE FROM sync_outbox
        WHERE entity_id IN (
          SELECT id FROM products WHERE business_id = ?
          UNION SELECT id FROM categories WHERE business_id = ?
          UNION SELECT id FROM sales WHERE business_id = ?
          UNION SELECT id FROM expenses WHERE business_id = ?
          UNION SELECT id FROM inventory_movements WHERE business_id = ?
          UNION SELECT id FROM queue_entries WHERE business_id = ?
          UNION SELECT pb.id FROM product_barcodes pb
            INNER JOIN products p ON p.id = pb.product_id
            WHERE p.business_id = ?
        )
        ''',
        [id, id, id, id, id, id, id],
      );

      await database.customStatement(
        '''
        DELETE FROM sync_conflicts
        WHERE entity_id IN (
          SELECT id FROM products WHERE business_id = ?
          UNION SELECT id FROM categories WHERE business_id = ?
          UNION SELECT id FROM sales WHERE business_id = ?
          UNION SELECT id FROM expenses WHERE business_id = ?
          UNION SELECT id FROM inventory_movements WHERE business_id = ?
          UNION SELECT id FROM queue_entries WHERE business_id = ?
          UNION SELECT pb.id FROM product_barcodes pb
            INNER JOIN products p ON p.id = pb.product_id
            WHERE p.business_id = ?
        )
        ''',
        [id, id, id, id, id, id, id],
      );

      await (database.delete(
        database.sales,
      )..where((row) => row.businessId.equals(id))).go();

      await (database.delete(
        database.inventoryMovements,
      )..where((row) => row.businessId.equals(id))).go();

      await (database.delete(
        database.products,
      )..where((row) => row.businessId.equals(id))).go();

      await (database.delete(
        database.categories,
      )..where((row) => row.businessId.equals(id))).go();

      await (database.delete(
        database.expenses,
      )..where((row) => row.businessId.equals(id))).go();

      await (database.delete(
        database.queueDailyCounters,
      )..where((row) => row.businessId.equals(id))).go();

      await (database.delete(
        database.businessDatasets,
      )..where((row) => row.id.equals(id))).go();
    });
  }
}
