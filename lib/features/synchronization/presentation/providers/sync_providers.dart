import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../data/repositories/sync_outbox_repository.dart';
import '../../data/services/sync_api_client.dart';
import '../../data/services/sync_auth_service.dart';
import '../../data/services/sync_settings_service.dart';
import '../../domain/services/sync_worker.dart';

final syncOutboxRepositoryProvider = Provider<SyncOutboxRepository>((ref) {
  return SyncOutboxRepository(ref.watch(databaseProvider));
});

final syncSettingsServiceProvider = Provider<SyncSettingsService>((ref) {
  return SyncSettingsService();
});

final syncAuthServiceProvider = Provider<SyncAuthService>((ref) {
  return SyncAuthService();
});

final syncWorkerProvider = Provider<SyncWorker>((ref) {
  return SyncWorker(
    database: ref.watch(databaseProvider),
    outbox: ref.watch(syncOutboxRepositoryProvider),
    settings: ref.watch(syncSettingsServiceProvider),
    apiClient: SyncApiClient(),
  );
});

final pendingSyncCountProvider = FutureProvider<int>((ref) async {
  return (await ref.watch(syncOutboxRepositoryProvider).pending()).length;
});
