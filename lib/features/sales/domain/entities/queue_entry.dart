class QueueEntry {
  final String id;
  final String saleId;
  final String queueDate;
  final int queueNumber;
  final String queueCode;
  final String status;
  final String preparationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QueueEntry({
    required this.id,
    required this.saleId,
    required this.queueDate,
    required this.queueNumber,
    required this.queueCode,
    required this.status,
    required this.preparationStatus,
    required this.createdAt,
    required this.updatedAt,
  });
}
