import 'dart:convert';

class DisasterReport {
  final int id;
  final int reporterId;
  final int categoryId;
  final String title;
  final String eventName;
  final String description;
  final String impactDetail;
  final String severity;
  final String latitude;
  final String longitude;
  final String address;
  final String village;
  final String district;
  final List<String> images;
  final DateTime incidentTime;
  final DateTime createdAt;
  final String status;
  final String? rejectionReason;
  final bool isPublic;
  final DisasterCategoryReport? category;
  final Reporter? reporter;

  DisasterReport({
    required this.id,
    required this.reporterId,
    required this.categoryId,
    required this.title,
    required this.eventName,
    required this.description,
    required this.impactDetail,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.village,
    required this.district,
    required this.images,
    required this.incidentTime,
    required this.createdAt,
    required this.status,
    this.rejectionReason,
    required this.isPublic,
    this.category,
    this.reporter,
  });

  factory DisasterReport.fromJson(Map<String, dynamic> json) {
    // Handle images parsing
    List<String> parsedImages = [];
    if (json['images'] != null) {
      if (json['images'] is String) {
        try {
          var decoded = jsonDecode(json['images']);
          if (decoded is List) {
            parsedImages = List<String>.from(decoded);
          }
        } catch (e) {
          // If parsing fails, maybe it's just a raw string or we leave it empty
          print('Error parsing images JSON: $e');
        }
      } else if (json['images'] is List) {
        parsedImages = List<String>.from(json['images']);
      }
    }

    return DisasterReport(
      id: json['id'],
      reporterId: json['reporter_id'],
      categoryId: json['category_id'],
      title: json['title'] ?? '',
      eventName: json['event_name'] ?? '',
      description: json['description'] ?? '',
      impactDetail: json['impact_detail'] ?? '',
      severity: json['severity'] ?? '',
      latitude: json['latitude'] ?? '',
      longitude: json['longitude'] ?? '',
      address: json['address'] ?? '',
      village: json['village'] ?? '',
      district: json['district'] ?? '',
      images: parsedImages,
      incidentTime: DateTime.parse(json['incident_time']),
      createdAt: DateTime.parse(json['created_at']),
      status: json['status'] ?? 'pending',
      rejectionReason: json['rejection_reason'],
      isPublic: json['is_public'] == true || json['is_public'] == 1,
      category: json['category'] != null
          ? DisasterCategoryReport.fromJson(json['category'])
          : null,
      reporter: json['reporter'] != null
          ? Reporter.fromJson(json['reporter'])
          : null,
    );
  }
}

class DisasterCategoryReport {
  final int id;
  final String name;
  final String? iconUrl;

  DisasterCategoryReport({required this.id, required this.name, this.iconUrl});

  factory DisasterCategoryReport.fromJson(Map<String, dynamic> json) {
    return DisasterCategoryReport(
      id: json['id'],
      name: json['name'] ?? '',
      iconUrl: json['icon_url'],
    );
  }
}

class Reporter {
  final int id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  Reporter({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  factory Reporter.fromJson(Map<String, dynamic> json) {
    return Reporter(
      id: json['id'],
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      avatarUrl: json['avatar_url'],
    );
  }
}
