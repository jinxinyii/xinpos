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
    required SyncOutboxRepository outbox,
    required SyncSettingsService settings,
    required SyncApiClient apiClient,
  }) : _outbox = outbox,
       _settings = settings,
       _apiClient = apiClient;

  final SyncOutboxRepository _outbox;
  final SyncSettingsService _settings;
  final SyncApiClient _apiClient;

  Future<SyncResult> syncPending() async {
    final configuration = await _settings.read();
    if (configuration == null) {
      return const SyncResult(sent: 0, failed: 0, isConfigured: false);
    }

    final pending = await _outbox.pending();
    if (pending.isEmpty) return const SyncResult(sent: 0, failed: 0, isConfigured: true);

    try {
      final acceptedIds = await _apiClient.submitBatch(
        apiBaseUrl: configuration.apiBaseUrl,
        accessToken: configuration.accessToken,
        changes: pending,
      );
      var sent = 0;
      var failed = 0;
      for (final change in pending) {
        if (acceptedIds.contains(change.id)) {
          await _outbox.markSynced(change.id);
          sent++;
        } else {
          await _outbox.recordFailure(change.id, 'The server did not accept this change.');
          failed++;
        }
      }
      return SyncResult(sent: sent, failed: failed, isConfigured: true);
    } catch (error) {
      for (final change in pending) {
        await _outbox.recordFailure(change.id, error);
      }
      return SyncResult(sent: 0, failed: pending.length, isConfigured: true);
    }
  }
}
