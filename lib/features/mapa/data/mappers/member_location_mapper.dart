import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:app/features/location/data/models/member_location_response.dart';
import 'package:app/features/mapa/presentation/widgets/family_map.dart';

MemberLocation toMemberLocation(MemberLocationResponse res) {
  final hasFirst = res.firstName?.isNotEmpty ?? false;
  final hasLast = res.lastName?.isNotEmpty ?? false;

  final fullName = hasFirst || hasLast
      ? [
          res.firstName,
          res.lastName,
        ].where((s) => s != null && s.isNotEmpty).join(' ')
      : 'Miembro';

  return MemberLocation(
    id: res.userId,
    userId: res.userId,
    name: fullName,
    initials: res.memberInitials,
    position: LatLng(res.latitude, res.longitude),
    color: _colorForUser(res.userId),
    lastSeenText: _getLastSeenText(res.updatedAt),
    recentTrail: res.recentTrail
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList(),
  );
}

Color _colorForUser(String userId) {
  final hash = userId.hashCode;

  final colors = [
    const Color(0xFFE9C9A0),
    const Color(0xFFC9AEDD),
    const Color(0xFFE9A0A0),
    const Color(0xFFA0D9E9),
    const Color(0xFFB8E9A0),
  ];

  return colors[hash.abs() % colors.length];
}

String _getLastSeenText(DateTime updatedAt) {
  final diff = DateTime.now().difference(updatedAt);

  if (diff.inMinutes < 2) return 'En vivo';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours}h';

  return 'Hace ${diff.inDays}d';
}