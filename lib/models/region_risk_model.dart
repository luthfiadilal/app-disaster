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
    return RegionRisk(
      regionId: json['region_id'],
      regionName: json['region_name'] ?? '',
      geom:
          json['geom'], // This might require specific GeoJSON parsing logic if we want to render it
      riskScore: double.tryParse(json['risk_score'].toString()) ?? 0.0,
      riskColor: json['risk_color'] ?? 'green',
      riskStatus: json['risk_status'] ?? 'Safe',
    );
  }
}
