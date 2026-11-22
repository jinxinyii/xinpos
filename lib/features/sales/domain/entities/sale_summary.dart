class SaleSummary {
  final String id;
  final String receiptNumber;
  final String? queueCode;
  final String status;
  final int subtotalCentavos;
  final int discountCentavos;
  final int totalCentavos;
  final DateTime soldAt;
  final int itemCount;
  final String paymentMethod;

  const SaleSummary({
    required this.id,
    required this.receiptNumber,
    required this.queueCode,
    required this.status,
    required this.subtotalCentavos,
    required this.discountCentavos,
    required this.totalCentavos,
    required this.soldAt,
    required this.itemCount,
    required this.paymentMethod,
  });
}
