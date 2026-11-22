class DashboardRecentSale {
  final String id;
  final String receiptNumber;
  final int totalCentavos;
  final DateTime soldAt;
  final String paymentMethod;
  final String status;

  const DashboardRecentSale({
    required this.id,
    required this.receiptNumber,
    required this.totalCentavos,
    required this.soldAt,
    required this.paymentMethod,
    required this.status,
  });
}

class DashboardData {
  final int totalSalesCentavos;
  final int transactionCount;
  final int cashSalesCentavos;
  final int gcashSalesCentavos;
  final List<DashboardRecentSale> recentSales;

  const DashboardData({
    required this.totalSalesCentavos,
    required this.transactionCount,
    required this.cashSalesCentavos,
    required this.gcashSalesCentavos,
    required this.recentSales,
  });
}
