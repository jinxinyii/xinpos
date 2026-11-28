import 'dart:convert';

import '../../../../core/database/app_database.dart';
import '../../data/repositories/sync_outbox_repository.dart';
import '../../data/services/sync_api_client.dart';
import '../../data/services/sync_settings_service.dart';

class SyncResult {
  const SyncResult({
    required this.sent,
    required this.failed,
    required this.isConfigured,
  });

  final int sent;
  final int failed;
  final bool isConfigured;
}

class SyncWorker {
  SyncWorker({
    required this.outbox,
    required this.settings,
    required this.apiClient,
  });

  final SyncOutboxRepository outbox;
  final SyncSettingsService settings;
  final SyncApiClient apiClient;

  Future<SyncResult> syncPending() async {
    final configuration = await settings.read();
    if (configuration == null) {
      return const SyncResult(sent: 0, failed: 0, isConfigured: false);
    }

    final pending = await outbox.pending();
    if (pending.isEmpty) {
      return const SyncResult(sent: 0, failed: 0, isConfigured: true);
    }

    final mappedChanges = <SyncOutboxData>[];
    final unmappedChanges = <SyncOutboxData>[];
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
      if (mappedChanges.isEmpty) {
        return SyncResult(
          sent: 0,
          failed: unmappedChanges.length,
          isConfigured: true,
        );
      }

      final acceptedIds = await apiClient.submitBatch(
        apiBaseUrl: configuration.apiBaseUrl,
        accessToken: configuration.accessToken,
        changes: mappedChanges,
      );
      var sent = 0;
      var failed = 0;
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
      return SyncResult(
        sent: sent,
        failed: failed + unmappedChanges.length,
        isConfigured: true,
      );
    } catch (error) {
      for (final change in mappedChanges) {
        await outbox.recordFailure(change.id, error);
      }
      return SyncResult(
        sent: 0,
        failed: mappedChanges.length + unmappedChanges.length,
        isConfigured: true,
      );
    }
  }
}
