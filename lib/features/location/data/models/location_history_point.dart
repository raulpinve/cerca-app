class LocationHistoryPoint {
  final double latitude;
  final double longitude;
  final DateTime recordedAt;

  LocationHistoryPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
  });

  factory LocationHistoryPoint.fromJson(Map<String, dynamic> json) {
    return LocationHistoryPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String).toLocal(),
    );
  }
}
