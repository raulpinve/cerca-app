class CircleResponse {
  final String id;
  final String name;
  final int memberCount;
  final List<String> memberInitials;
  final String role;

  CircleResponse({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.memberInitials,
    required this.role,
  });

  factory CircleResponse.fromJson(Map<String, dynamic> json) {
    return CircleResponse(
      id: json['id'] as String,
      name: json['name'] as String,
      memberCount: _parseInt(json['memberCount']),
      memberInitials: (json['memberInitials'] as List)
          .map((e) => e as String)
          .toList(),
      role: json['role'] as String? ?? 'member',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
