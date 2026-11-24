import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/database_provider.dart';
import '../../domain/entities/queue_entry.dart';
import '../../domain/entities/queue_summary.dart';
import 'sale_providers.dart';

final todayQueueProvider = StreamProvider<List<QueueEntry>>((ref) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return database
      .customSelect(
        'SELECT 1 FROM queue_entries',
        readsFrom: {database.queueEntries},
      )
      .watch()
      .asyncMap((_) => repository.getTodayQueue());
});

final todayQueueSummaryProvider = StreamProvider<QueueSummary>((ref) {
  final database = ref.watch(databaseProvider);
  final repository = ref.watch(saleRepositoryProvider);
  return database
      .customSelect(
        'SELECT 1 FROM queue_entries',
        readsFrom: {database.queueEntries},
      )
      .watch()
      .asyncMap((_) => repository.getTodayQueueSummary());
});
