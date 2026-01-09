class DisasterCategory {
  final int id;
  final String name;
  final String? iconUrl;

  DisasterCategory({required this.id, required this.name, this.iconUrl});

  factory DisasterCategory.fromJson(Map<String, dynamic> json) {
    return DisasterCategory(
      id: json['id'],
      name: json['name'],
      iconUrl: json['icon_url'],
    );
  }
}
