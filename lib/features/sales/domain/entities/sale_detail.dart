class SaleDetail {
  final String id;
  final String receiptNumber;
  final String? queueCode;
  final String status;
  final int subtotalCentavos;
  final int discountCentavos;
  final int totalCentavos;
  final DateTime soldAt;
  final List<SaleDetailItem> items;
  final SalePaymentDetail? payment;

  const SaleDetail({
    required this.id,
    required this.receiptNumber,
    required this.queueCode,
    required this.status,
    required this.subtotalCentavos,
    required this.discountCentavos,
    required this.totalCentavos,
    required this.soldAt,
    required this.items,
    required this.payment,
  });
}

class SaleDetailItem {
  final String productName;
  final String? sku;
  final int quantity;
  final int unitPriceCentavos;
  final int unitCostCentavos;
  final int lineTotalCentavos;

  const SaleDetailItem({
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPriceCentavos,
    required this.unitCostCentavos,
    required this.lineTotalCentavos,
  });
}

class SalePaymentDetail {
  final String method;
  final int amountCentavos;
  final int? amountTenderedCentavos;
  final String? referenceNumber;
  final DateTime paidAt;

  const SalePaymentDetail({
    required this.method,
    required this.amountCentavos,
    required this.amountTenderedCentavos,
    required this.referenceNumber,
    required this.paidAt,
  });
}
