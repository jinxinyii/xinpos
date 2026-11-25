class BusinessDatasetSummary {
  const BusinessDatasetSummary({
    required this.id,
    required this.name,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final bool isArchived;
  final int createdAt;
  final int updatedAt;
}
