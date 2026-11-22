class BusinessExpense {
  final String id;
  final String description;
  final String category;
  final int amountCentavos;
  final String? paymentMethod;
  final DateTime expenseDate;
  final DateTime createdAt;

  const BusinessExpense({
    required this.id,
    required this.description,
    required this.category,
    required this.amountCentavos,
    required this.paymentMethod,
    required this.expenseDate,
    required this.createdAt,
  });
}
