import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:xinpos/shared/widgets/app_notification.dart';

import '../../domain/entities/queue_entry.dart';
import '../providers/queue_providers.dart';
import '../providers/sale_providers.dart';

void _showQueueNotification(
  BuildContext context,
  String message, {
  String title = 'Queue updated',
  IconData icon = Icons.check_rounded,
  bool isError = false,
}) {
  AppNotification.show(
    context,
    message: title == 'Queue updated' ? message : '$title: $message',
    type: isError || icon == Icons.error_outline_rounded
        ? AppNotificationType.error
        : AppNotificationType.success,
  );
}

class QueueManagementScreen extends ConsumerWidget {
  const QueueManagementScreen({super.key});

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      ref.invalidate(todayQueueProvider);
      ref.invalidate(todayQueueSummaryProvider);
    } catch (error) {
      if (!context.mounted) return;
      _showQueueNotification(
        context,
        error.toString().replaceFirst('Bad state: ', ''),
        title: 'Queue action failed',
        isError: true,
      );
    }
  }

  Future<void> _confirmSkip(
    BuildContext context,
    WidgetRef ref,
    QueueEntry entry,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Skip queue entry?'),
        content: Text('Are you sure you want to skip ${entry.queueCode}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Skip'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (confirmed == true) {
      await _runAction(
        context,
        ref,
        () => ref.read(saleRepositoryProvider).skipQueueEntry(entry.id),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(todayQueueProvider);
    final summaryAsync = ref.watch(todayQueueSummaryProvider);
    final colors = Theme.of(context).colorScheme;
    final today = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh queue',
            onPressed: () {
              ref.invalidate(todayQueueProvider);
              ref.invalidate(todayQueueSummaryProvider);
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: queueAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ErrorView(
          message: error.toString(),
          onRetry: () {
            ref.invalidate(todayQueueProvider);
            ref.invalidate(todayQueueSummaryProvider);
          },
        ),
        data: (entries) {
          final servingEntries = entries
              .where((entry) => entry.status == 'serving')
              .toList();
          final serving = servingEntries.isEmpty ? null : servingEntries.first;
          final waiting = entries
              .where((entry) => entry.status == 'waiting')
              .toList();
          final ready = waiting
              .where((entry) => entry.preparationStatus == 'ready')
              .toList();
          final preparing = waiting
              .where((entry) => entry.preparationStatus != 'ready')
              .toList();
          final completed = entries
              .where((entry) => entry.status == 'completed')
              .toList();
          final skipped = entries
              .where((entry) => entry.status == 'skipped')
              .toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 760;
              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(todayQueueProvider);
                  ref.invalidate(todayQueueSummaryProvider);
                  await ref.read(todayQueueProvider.future);
                },
                child: ListView(
                  padding: EdgeInsets.all(wide ? 24 : 16),
                  children: [
                    Text(
                      today,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    summaryAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (summary) => GridView.count(
                        crossAxisCount: wide ? 4 : 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: wide ? 2.3 : 2.0,
                        children: [
                          _StatCard(
                            label: 'Waiting',
                            value: summary.waiting,
                            icon: Icons.groups_outlined,
                          ),
                          _StatCard(
                            label: 'Serving',
                            value: summary.serving,
                            icon: Icons.record_voice_over_outlined,
                          ),
                          _StatCard(
                            label: 'Completed',
                            value: summary.completed,
                            icon: Icons.check_circle_outline,
                          ),
                          _StatCard(
                            label: 'Skipped',
                            value: summary.skipped,
                            icon: Icons.skip_next_outlined,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ServingCard(
                      entry: serving,
                      onComplete: serving == null
                          ? null
                          : () => _runAction(
                              context,
                              ref,
                              () => ref
                                  .read(saleRepositoryProvider)
                                  .completeQueueEntry(serving.id),
                            ),
                      onSkip: serving == null
                          ? null
                          : () => _confirmSkip(context, ref, serving),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: serving != null
                                ? null
                                : () async {
                                    try {
                                      final next = await ref
                                          .read(saleRepositoryProvider)
                                          .callNextQueueEntry();
                                      ref.invalidate(todayQueueProvider);
                                      ref.invalidate(todayQueueSummaryProvider);
                                      if (!context.mounted) return;
                                      _showQueueNotification(
                                        context,
                                        next == null
                                            ? 'No customers waiting.'
                                            : '${next.queueCode} is now serving.',
                                        title: next == null
                                            ? 'Queue is empty'
                                            : 'Customer called',
                                        icon: next == null
                                            ? Icons.info_outline_rounded
                                            : Icons.campaign_outlined,
                                      );
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      _showQueueNotification(
                                        context,
                                        error.toString().replaceFirst(
                                          'Bad state: ',
                                          '',
                                        ),
                                        title: 'Queue action failed',
                                        isError: true,
                                      );
                                    }
                                  },
                            icon: const Icon(Icons.campaign_outlined),
                            label: const Text('Call Next'),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: serving != null
                                ? null
                                : () async {
                                    try {
                                      final next = await ref
                                          .read(saleRepositoryProvider)
                                          .callNextReadyQueueEntry();
                                      ref.invalidate(todayQueueProvider);
                                      ref.invalidate(todayQueueSummaryProvider);
                                      if (!context.mounted) return;
                                      _showQueueNotification(
                                        context,
                                        next == null
                                            ? 'No ready orders available.'
                                            : '${next.queueCode} is now serving.',
                                        title: next == null
                                            ? 'No ready orders'
                                            : 'Ready order called',
                                        icon: next == null
                                            ? Icons.info_outline_rounded
                                            : Icons.campaign_outlined,
                                      );
                                    } catch (error) {
                                      if (!context.mounted) return;
                                      _showQueueNotification(
                                        context,
                                        error.toString().replaceFirst(
                                          'Bad state: ',
                                          '',
                                        ),
                                        title: 'Queue action failed',
                                        isError: true,
                                      );
                                    }
                                  },
                            icon: const Icon(
                              Icons.notifications_active_outlined,
                            ),
                            label: const Text('Call Ready'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _QueueSection(
                      title: 'Ready for Pickup',
                      count: ready.length,
                      emptyText: 'No orders are ready yet.',
                      entries: ready,
                      actionLabel: 'Call Ready',
                      onAction: (entry) => _runAction(
                        context,
                        ref,
                        () => ref
                            .read(saleRepositoryProvider)
                            .markQueueEntryReady(entry.id),
                      ),
                      onSkip: (entry) => _confirmSkip(context, ref, entry),
                    ),
                    const SizedBox(height: 18),
                    _QueueSection(
                      title: 'Preparing',
                      count: preparing.length,
                      emptyText: 'No orders are being prepared.',
                      entries: preparing,
                      actionLabel: 'Mark Ready',
                      onAction: (entry) => _runAction(
                        context,
                        ref,
                        () => ref
                            .read(saleRepositoryProvider)
                            .markQueueEntryReady(entry.id),
                      ),
                      onSkip: (entry) => _confirmSkip(context, ref, entry),
                    ),
                    if (completed.isNotEmpty || skipped.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Today’s Activity',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ...entries
                          .where(
                            (entry) =>
                                entry.status == 'completed' ||
                                entry.status == 'skipped',
                          )
                          .toList()
                          .reversed
                          .map((entry) => _QueueEntryCard(entry: entry)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _QueueSection extends StatelessWidget {
  final String title;
  final int count;
  final String emptyText;
  final List<QueueEntry> entries;
  final String actionLabel;
  final ValueChanged<QueueEntry>? onAction;
  final ValueChanged<QueueEntry> onSkip;

  const _QueueSection({
    required this.title,
    required this.count,
    required this.emptyText,
    required this.entries,
    required this.actionLabel,
    this.onAction,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text('$count', style: theme.textTheme.labelLarge),
          ],
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Center(child: Text(emptyText)),
            ),
          )
        else
          ...entries.map(
            (entry) => _QueueEntryCard(
              entry: entry,
              actionLabel: actionLabel,
              onAction: onAction == null ? null : () => onAction!(entry),
              onSkip: () => onSkip(entry),
            ),
          ),
      ],
    );
  }
}

class _ServingCard extends StatelessWidget {
  final QueueEntry? entry;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const _ServingCard({
    required this.entry,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NOW SERVING',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.onPrimaryContainer,
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                entry?.queueCode ?? '—',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (entry == null)
              Center(
                child: Text(
                  'No customer is currently being served.',
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSkip,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Skip'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onComplete,
                      icon: const Icon(Icons.check),
                      label: const Text('Complete'),
                    ),
                  ),
                ],
              ),
            if (entry != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    _showQueueNotification(
                      context,
                      'Now serving ${entry!.queueCode}',
                      title: 'Queue number recalled',
                      icon: Icons.campaign_outlined,
                    );
                  },
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('Recall Number'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueEntryCard extends StatelessWidget {
  final QueueEntry entry;
  final VoidCallback? onSkip;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _QueueEntryCard({
    required this.entry,
    this.onSkip,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = switch (entry.status) {
      'completed' => colors.tertiary,
      'skipped' => colors.error,
      'serving' => colors.primary,
      _ => colors.onSurfaceVariant,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colors.surfaceContainerHighest,
          child: Text(
            '${entry.queueNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          entry.queueCode,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(DateFormat('h:mm a').format(entry.createdAt)),
        trailing: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          children: [
            Text(
              entry.status == 'waiting'
                  ? entry.preparationStatus.toUpperCase()
                  : entry.status.toUpperCase(),
              style: TextStyle(
                color:
                    entry.preparationStatus == 'ready' &&
                        entry.status == 'waiting'
                    ? colors.tertiary
                    : statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            if (onSkip != null)
              IconButton(
                tooltip: 'Skip ${entry.queueCode}',
                onPressed: onSkip,
                icon: const Icon(Icons.skip_next_outlined),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            const Text('Unable to load queue.'),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }
}
