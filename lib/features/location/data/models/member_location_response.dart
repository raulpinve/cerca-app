import 'dart:convert';

import 'package:flutter/rendering.dart';

class TrailPoint {
  final double latitude;
  final double longitude;

  TrailPoint({required this.latitude, required this.longitude});

  factory TrailPoint.fromJson(Map<String, dynamic> json) {
    return TrailPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class MemberLocationResponse {
  final String deviceId;
  final String userId;
  final String? firstName;
  final String? lastName;
  final String memberInitials;
  final double latitude;
  final double longitude;
  final double accuracyM;
  final DateTime updatedAt;
  final List<TrailPoint> recentTrail;

  MemberLocationResponse({
    required this.deviceId,
    required this.userId,
    this.firstName,
    this.lastName,
    required this.memberInitials,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.updatedAt,
    required this.recentTrail,
  });

  factory MemberLocationResponse.fromJson(Map<String, dynamic> json) {
    return MemberLocationResponse(
      deviceId: json['deviceId'] as String,
      userId: json['userId'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      memberInitials: json['memberInitials'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      accuracyM: (json['accuracyM'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      recentTrail: (json['recentTrail'] as List)
          .map((e) => TrailPoint.fromJson(e))
          .toList(),
    );
  }
}
