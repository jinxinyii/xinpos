class QueueSummary {
  final int waiting;
  final int serving;
  final int completed;
  final int skipped;

  const QueueSummary({
    required this.waiting,
    required this.serving,
    required this.completed,
    required this.skipped,
  });
}
