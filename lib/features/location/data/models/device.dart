class Device {
  final String id;
  final String userId;
  final String deviceName;
  final String platform;

  Device({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.platform,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      userId: json['userId'] as String,
      deviceName: json['deviceName'] as String,
      platform: json['platform'] as String,
    );
  }
}
