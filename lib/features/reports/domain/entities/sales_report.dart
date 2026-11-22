class SalesReport {
  final int totalRevenueCentavos;
  final int transactionCount;
  final int totalItemsSold;
  final int averageTransactionCentavos;
  final List<DailySalesPoint> dailySales;
  final List<TopProductSales> topProducts;
  final List<PaymentMethodSales> paymentMethods;
  final List<CategorySales> categorySales;

  const SalesReport({
    required this.totalRevenueCentavos,
    required this.transactionCount,
    required this.totalItemsSold,
    required this.averageTransactionCentavos,
    required this.dailySales,
    required this.topProducts,
    required this.paymentMethods,
    required this.categorySales,
  });
}

class DailySalesPoint {
  final DateTime date;
  final int revenueCentavos;
  final int transactionCount;

  const DailySalesPoint({
    required this.date,
    required this.revenueCentavos,
    required this.transactionCount,
  });
}

class TopProductSales {
  final String productName;
  final int quantitySold;
  final int revenueCentavos;

  const TopProductSales({
    required this.productName,
    required this.quantitySold,
    required this.revenueCentavos,
  });
}

class PaymentMethodSales {
  final String method;
  final int amountCentavos;
  final int transactionCount;

  const PaymentMethodSales({
    required this.method,
    required this.amountCentavos,
    required this.transactionCount,
  });
}

class CategorySales {
  final String categoryName;
  final int quantitySold;
  final int revenueCentavos;

  const CategorySales({
    required this.categoryName,
    required this.quantitySold,
    required this.revenueCentavos,
  });
}
