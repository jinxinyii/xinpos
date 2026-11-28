import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/sync_outbox_repository.dart';
import '../../data/services/sync_api_client.dart';
import '../../data/services/sync_settings_service.dart';

class SyncResult {
  const SyncResult({
    required this.sent,
    required this.received,
    required this.failed,
    required this.isConfigured,
    this.errorMessage,
  });

  final int sent;
  final int received;
  final int failed;
  final bool isConfigured;
  final String? errorMessage;
}

class SyncWorker {
  SyncWorker({
    required this.database,
    required this.outbox,
    required this.settings,
    required this.apiClient,
  });

  final SyncOutboxRepository outbox;
  final AppDatabase database;
  final SyncSettingsService settings;
  final SyncApiClient apiClient;

  Future<SyncResult> syncPending() async {
    final configuration = await settings.read();
    if (configuration == null) {
      return const SyncResult(
        sent: 0,
        received: 0,
        failed: 0,
        isConfigured: false,
      );
    }

    final pending = await outbox.pending();
    final mappedChanges = <SyncOutboxData>[];
    final unmappedChanges = <SyncOutboxData>[];
    var sent = 0;
    var failed = 0;
    var received = 0;
    try {
      final mappings = await settings.businessMappings();
      for (final change in pending) {
        final payload = jsonDecode(change.payloadJson);
        if (payload is! Map<String, dynamic> || payload['businessId'] is! String) {
          unmappedChanges.add(change);
          continue;
        }
        final remoteBusinessId = mappings[payload['businessId'] as String];
        if (remoteBusinessId == null) {
          unmappedChanges.add(change);
          continue;
        }
        payload['localBusinessId'] = payload['businessId'];
        payload['businessId'] = remoteBusinessId;
        mappedChanges.add(change.copyWith(payloadJson: jsonEncode(payload)));
      }
      for (final change in unmappedChanges) {
        await outbox.recordFailure(
          change.id,
          'No server business is linked to this local business.',
        );
      }
      if (mappedChanges.isNotEmpty) {
        final acceptedIds = await apiClient.submitBatch(
          apiBaseUrl: configuration.apiBaseUrl,
          accessToken: configuration.accessToken,
          changes: mappedChanges,
        );
        for (final change in mappedChanges) {
          if (acceptedIds.contains(change.id)) {
            await outbox.markSynced(change.id);
            sent++;
          } else {
            await outbox.recordFailure(
              change.id,
              'The server did not accept this change.',
            );
            failed++;
          }
        }
      }

      for (final mapping in mappings.entries) {
        received += await _pullBusinessChanges(
          configuration,
          localBusinessId: mapping.key,
          remoteBusinessId: mapping.value,
        );
      }
      return SyncResult(
        sent: sent,
        received: received,
        failed: failed + unmappedChanges.length,
        isConfigured: true,
      );
    } catch (error) {
      for (final change in mappedChanges) {
        await outbox.recordFailure(change.id, error);
      }
      return SyncResult(
        sent: sent,
        received: received,
        failed: failed + unmappedChanges.length + (mappedChanges.length - sent - failed),
        isConfigured: true,
        errorMessage: error.toString(),
      );
    }
  }

  Future<int> _pullBusinessChanges(
    SyncSettings configuration, {
    required String localBusinessId,
    required String remoteBusinessId,
  }) async {
    final stateKey = 'sync_cursor:$remoteBusinessId';
    final state = await (database.select(database.syncState)
          ..where((row) => row.key.equals(stateKey)))
        .getSingleOrNull();
    var cursor = int.tryParse(state?.value ?? '') ?? 0;
    var received = 0;

    while (true) {
      final response = await apiClient.fetchChanges(
        apiBaseUrl: configuration.apiBaseUrl,
        accessToken: configuration.accessToken,
        businessId: remoteBusinessId,
        cursor: cursor,
      );
      if (response.changes.isEmpty) break;

      await database.transaction(() async {
        for (final change in response.changes) {
          await _applyRemoteChange(localBusinessId, change);
        }
        await database.into(database.syncState).insertOnConflictUpdate(
          SyncStateCompanion.insert(
            key: stateKey,
            value: response.nextCursor.toString(),
          ),
        );
      });
      received += response.changes.length;
      cursor = response.nextCursor;
    }
    return received;
  }

  Future<void> _applyRemoteChange(
    String businessId,
    RemoteSyncChange change,
  ) async {
    final payload = change.payload;
    switch (change.entityType) {
      case 'category':
        final existing = await (database.select(database.categories)
              ..where((row) => row.id.equals(change.entityId))
              ..where((row) => row.businessId.equals(businessId)))
            .getSingleOrNull();
        final updatedAt = _requiredInt(payload, 'updatedAt');
        if (existing != null && existing.updatedAt > updatedAt) return;
        await database.into(database.categories).insertOnConflictUpdate(
          CategoriesCompanion.insert(
            businessId: Value(businessId),
            id: change.entityId,
            name: _requiredString(payload, 'name', existing?.name),
            description: Value(payload['description'] as String? ?? existing?.description),
            isActive: Value(payload['isActive'] as bool? ?? existing?.isActive ?? true),
            createdAt: _requiredInt(payload, 'createdAt', existing?.createdAt),
            updatedAt: updatedAt,
          ),
        );
        return;
      case 'product':
        final existing = await (database.select(database.products)
              ..where((row) => row.id.equals(change.entityId))
              ..where((row) => row.businessId.equals(businessId)))
            .getSingleOrNull();
        final updatedAt = _requiredInt(payload, 'updatedAt');
        if (existing != null && existing.updatedAt > updatedAt) return;
        await database.into(database.products).insertOnConflictUpdate(
          ProductsCompanion.insert(
            businessId: Value(businessId),
            id: change.entityId,
            categoryId: Value(payload['categoryId'] as String? ?? existing?.categoryId),
            name: _requiredString(payload, 'name', existing?.name),
            sku: Value(payload['sku'] as String? ?? existing?.sku),
            description: Value(payload['description'] as String? ?? existing?.description),
            costPriceCentavos: _requiredInt(payload, 'costPriceCentavos', existing?.costPriceCentavos),
            sellingPriceCentavos: _requiredInt(payload, 'sellingPriceCentavos', existing?.sellingPriceCentavos),
            reorderLevel: Value(
              payload['reorderLevel'] as int? ?? existing?.reorderLevel ?? 0,
            ),
            trackInventory: Value(
              payload['trackInventory'] as bool? ??
                  existing?.trackInventory ??
                  true,
            ),
            isActive: Value(
              payload['isActive'] as bool? ?? existing?.isActive ?? true,
            ),
            createdAt: _requiredInt(payload, 'createdAt', existing?.createdAt),
            updatedAt: updatedAt,
          ),
        );
        return;
      case 'inventory_movement':
        await database.into(database.inventoryMovements).insert(
          InventoryMovementsCompanion.insert(
            businessId: Value(businessId),
            id: change.entityId,
            productId: Value(_requiredString(payload, 'productId')),
            productNameSnapshot: _requiredString(payload, 'productNameSnapshot'),
            movementType: _requiredString(payload, 'movementType'),
            quantityDelta: _requiredInt(payload, 'quantityDelta'),
            referenceType: Value(payload['referenceType'] as String?),
            referenceId: Value(payload['referenceId'] as String?),
            note: Value(payload['note'] as String?),
            createdAt: _requiredInt(payload, 'createdAt'),
          ),
          mode: InsertMode.insertOrIgnore,
        );
        return;
      case 'sale':
        await _applyRemoteSale(businessId, change.entityId, payload);
        return;
      default:
        throw SyncApiException('Unsupported server entity: ${change.entityType}.');
    }
  }

  String _requiredString(
    Map<String, dynamic> payload,
    String key, [
    String? fallback,
  ]) {
    final value = payload[key] ?? fallback;
    if (value is String && value.isNotEmpty) return value;
    throw SyncApiException('Server change is missing $key.');
  }

  int _requiredInt(Map<String, dynamic> payload, String key, [int? fallback]) {
    final value = payload[key] ?? fallback;
    if (value is int) return value;
    throw SyncApiException('Server change has an invalid $key.');
  }

  Future<void> _applyRemoteSale(
    String businessId,
    String saleId,
    Map<String, dynamic> payload,
  ) async {
    final existing = await (database.select(database.sales)
          ..where((row) => row.id.equals(saleId))
          ..where((row) => row.businessId.equals(businessId)))
        .getSingleOrNull();
    final updatedAt = _requiredInt(payload, 'updatedAt');
    if (existing != null && existing.updatedAt > updatedAt) return;

    await database.into(database.sales).insertOnConflictUpdate(
      SalesCompanion.insert(
        businessId: Value(businessId),
        id: saleId,
        receiptNumber: _requiredString(payload, 'receiptNumber'),
        status: Value(payload['status'] as String? ?? 'completed'),
        subtotalCentavos: _requiredInt(payload, 'subtotalCentavos'),
        discountCentavos: Value(payload['discountCentavos'] as int? ?? 0),
        totalCentavos: _requiredInt(payload, 'totalCentavos'),
        soldAt: _requiredInt(payload, 'soldAt'),
        createdAt: _requiredInt(payload, 'createdAt'),
        updatedAt: updatedAt,
      ),
    );

    final items = payload['items'];
    final payment = payload['payment'];
    if (items is! List || payment is! Map<String, dynamic>) {
      throw const SyncApiException('Server sale is missing its items or payment.');
    }
    for (final value in items) {
      if (value is! Map<String, dynamic>) {
        throw const SyncApiException('Server sale item is invalid.');
      }
      await database.into(database.saleItems).insert(
        SaleItemsCompanion.insert(
          businessId: Value(businessId),
          id: _requiredString(value, 'id'),
          saleId: saleId,
          productId: Value(value['productId'] as String?),
          productName: _requiredString(value, 'productName'),
          sku: Value(value['sku'] as String?),
          quantity: _requiredInt(value, 'quantity'),
          unitPriceCentavos: _requiredInt(value, 'unitPriceCentavos'),
          unitCostCentavos: _requiredInt(value, 'unitCostCentavos'),
          lineTotalCentavos: _requiredInt(value, 'lineTotalCentavos'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    await database.into(database.payments).insert(
      PaymentsCompanion.insert(
        businessId: Value(businessId),
        id: _requiredString(payment, 'id'),
        saleId: saleId,
        method: _requiredString(payment, 'method'),
        amountCentavos: _requiredInt(payment, 'amountCentavos'),
        amountTenderedCentavos: Value(payment['amountTenderedCentavos'] as int?),
        referenceNumber: Value(payment['referenceNumber'] as String?),
        paidAt: _requiredInt(payment, 'paidAt'),
      ),
      mode: InsertMode.insertOrIgnore,
    );
    final movements = payload['inventoryMovements'] ?? const [];
    if (movements is! List) {
      throw const SyncApiException('Server sale inventory movements are invalid.');
    }
    for (final value in movements) {
      if (value is! Map<String, dynamic>) {
        throw const SyncApiException('Server sale inventory movement is invalid.');
      }
      await database.into(database.inventoryMovements).insert(
        InventoryMovementsCompanion.insert(
          businessId: Value(businessId),
          id: _requiredString(value, 'id'),
          productId: Value(_requiredString(value, 'productId')),
          productNameSnapshot: _requiredString(value, 'productNameSnapshot'),
          movementType: _requiredString(value, 'movementType'),
          quantityDelta: _requiredInt(value, 'quantityDelta'),
          referenceType: Value(value['referenceType'] as String?),
          referenceId: Value(value['referenceId'] as String?),
          note: Value(value['note'] as String?),
          createdAt: _requiredInt(value, 'createdAt'),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }
}
