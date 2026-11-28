import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/app_database.dart';

/// Stores local mutations until a synchronization worker sends them to the API.
class SyncOutboxRepository {
  SyncOutboxRepository(this.database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    return database
        .into(database.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            id: _uuid.v4(),
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payloadJson: jsonEncode(payload),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  Future<List<SyncOutboxData>> pending({int limit = 100}) {
    return (database.select(database.syncOutbox)
          ..where((row) => row.status.equals('pending'))
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> recordFailure(String id, Object error) {
    return database.customStatement(
      'UPDATE sync_outbox '
      'SET attempts = attempts + 1, last_error = ? '
      'WHERE id = ? AND status = \'pending\'',
      [error.toString(), id],
    );
  }

  Future<void> markSynced(String id) {
    return (database.update(
      database.syncOutbox,
    )..where((row) => row.id.equals(id))).write(
      SyncOutboxCompanion(
        status: const Value('synced'),
        lastError: const Value(null),
        syncedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
