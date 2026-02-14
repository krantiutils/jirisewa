class ProduceCategory {
  final String id;
  final String nameEn;
  final String nameNe;
  final String? icon;
  final int sortOrder;

  const ProduceCategory({
    required this.id,
    required this.nameEn,
    required this.nameNe,
    this.icon,
    this.sortOrder = 0,
  });

  String name(String lang) => lang == 'ne' ? nameNe : nameEn;

  factory ProduceCategory.fromJson(Map<String, dynamic> json) {
    return ProduceCategory(
      id: json['id'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameNe: json['name_ne'] as String? ?? '',
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}
