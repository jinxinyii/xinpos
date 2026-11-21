class Category {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final int createdAt;
  final int updatedAt;

  const Category({
    required this.id,
    required this.name,
    this.description,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });
}
