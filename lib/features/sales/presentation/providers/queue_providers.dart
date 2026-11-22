import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/queue_entry.dart';
import '../../domain/entities/queue_summary.dart';
import 'sale_providers.dart';

final todayQueueProvider = FutureProvider<List<QueueEntry>>((ref) {
  return ref.watch(saleRepositoryProvider).getTodayQueue();
});

final todayQueueSummaryProvider = FutureProvider<QueueSummary>((ref) {
  return ref.watch(saleRepositoryProvider).getTodayQueueSummary();
});
