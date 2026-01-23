class RegionRisk {
  final int regionId;
  final String regionName;
  final dynamic
  geom; // Can be complex parsed GeoJSON later, for now just keep as dynamic or String if needed
  final double riskScore;
  final String riskColor;
  final String riskStatus;

  RegionRisk({
    required this.regionId,
    required this.regionName,
    this.geom,
    required this.riskScore,
    required this.riskColor,
    required this.riskStatus,
  });

  factory RegionRisk.fromJson(Map<String, dynamic> json) {
    try {
      return RegionRisk(
        regionId: json['region_id'] is String
            ? int.tryParse(json['region_id']) ?? 0
            : (json['region_id'] ?? 0),
        regionName: json['region_name']?.toString() ?? '',
        geom:
            json['geom'], // This might require specific GeoJSON parsing logic if we want to render it
        riskScore: json['risk_score'] is String
            ? double.tryParse(json['risk_score']) ?? 0.0
            : (json['risk_score']?.toDouble() ?? 0.0),
        riskColor: json['risk_color']?.toString() ?? 'green',
        riskStatus: json['risk_status']?.toString() ?? 'Safe',
      );
    } catch (e) {
      // Log error and return a default safe object
      print('[RegionRisk] Error parsing JSON: $e');
      print('[RegionRisk] JSON data: $json');
      return RegionRisk(
        regionId: 0,
        regionName: 'Unknown',
        geom: null,
        riskScore: 0.0,
        riskColor: 'green',
        riskStatus: 'Safe',
      );
    }
  }
}
