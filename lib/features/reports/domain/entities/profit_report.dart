class DailyProfitPoint {
  final DateTime date;
  final int revenueCentavos;
  final int cogsCentavos;
  final int expensesCentavos;
  final int netProfitCentavos;

  const DailyProfitPoint({
    required this.date,
    required this.revenueCentavos,
    required this.cogsCentavos,
    required this.expensesCentavos,
    required this.netProfitCentavos,
  });
}

class ExpenseCategoryTotal {
  final String category;
  final int amountCentavos;

  const ExpenseCategoryTotal({
    required this.category,
    required this.amountCentavos,
  });
}

class ProductProfit {
  final String productName;
  final int quantitySold;
  final int revenueCentavos;
  final int cogsCentavos;
  final int grossProfitCentavos;

  const ProductProfit({
    required this.productName,
    required this.quantitySold,
    required this.revenueCentavos,
    required this.cogsCentavos,
    required this.grossProfitCentavos,
  });
}

class ProfitReport {
  final int revenueCentavos;
  final int costOfGoodsSoldCentavos;
  final int grossProfitCentavos;
  final int operatingExpensesCentavos;
  final int netProfitCentavos;
  final int transactionCount;
  final int itemsSold;
  final double profitMarginPercent;
  final List<DailyProfitPoint> dailyProfit;
  final List<ExpenseCategoryTotal> expenseCategories;
  final List<ProductProfit> topProducts;

  const ProfitReport({
    required this.revenueCentavos,
    required this.costOfGoodsSoldCentavos,
    required this.grossProfitCentavos,
    required this.operatingExpensesCentavos,
    required this.netProfitCentavos,
    required this.transactionCount,
    required this.itemsSold,
    required this.profitMarginPercent,
    required this.dailyProfit,
    required this.expenseCategories,
    required this.topProducts,
  });
}
