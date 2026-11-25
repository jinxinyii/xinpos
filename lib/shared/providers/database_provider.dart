import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/logging/app_logger.dart';
import '../../features/settings/data/services/backup_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  unawaited(
    BackupService(database).createDailyBackupIfNeeded().then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.instance.error(
          'Automatic database backup failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
    ),
  );

  ref.onDispose(() {
    database.close();
  });

  return database;
});
