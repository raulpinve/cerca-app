class CircleInvitation {
  final String id;
  final String circleId;
  final String circleName;
  final String invitedByFirstName;
  final String? invitedByLastName;
  final DateTime expiresAt;
  final DateTime createdAt;

  CircleInvitation({
    required this.id,
    required this.circleId,
    required this.circleName,
    required this.invitedByFirstName,
    this.invitedByLastName,
    required this.expiresAt,
    required this.createdAt,
  });

  String get invitedByFullName => invitedByLastName != null
      ? '$invitedByFirstName $invitedByLastName'
      : invitedByFirstName;

  factory CircleInvitation.fromJson(Map<String, dynamic> json) {
    return CircleInvitation(
      id: json['id'] as String,
      circleId: json['circleId'] as String,
      circleName: json['circleName'] as String,
      invitedByFirstName: json['invitedByFirstName'] as String? ?? 'Alguien',
      invitedByLastName: json['invitedByLastName'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
