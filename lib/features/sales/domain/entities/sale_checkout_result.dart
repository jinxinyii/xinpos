class SaleCheckoutResult {
  final String saleId;
  final String receiptNumber;
  final int subtotalCentavos;
  final int totalCentavos;
  final int changeCentavos;

  const SaleCheckoutResult({
    required this.saleId,
    required this.receiptNumber,
    required this.subtotalCentavos,
    required this.totalCentavos,
    required this.changeCentavos,
  });
}
