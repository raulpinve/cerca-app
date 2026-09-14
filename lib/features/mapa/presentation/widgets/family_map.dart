import 'package:app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Ubicación de un miembro para pintar en el mapa, con su recorrido reciente.
class MemberLocation {
  final String id; // userId - para navegar a perfil en el futuro
  final String deviceId; // deviceId - para pedir historial de ubicaciones
  final String name;
  final String initials;
  final LatLng position;
  final Color color;
  final String lastSeenText;
  final List<LatLng> recentTrail;

  MemberLocation({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.initials,
    required this.position,
    required this.color,
    required this.lastSeenText,
    required this.recentTrail,
  });
}

class FamilyMap extends StatefulWidget {
  final List<MemberLocation> members;
  final LatLng initialCenter;
  final MapController? controller;

  final String cartoApiKey;

  final void Function(MemberLocation member)? onViewFullHistory;

  const FamilyMap({
    super.key,
    required this.members,
    required this.cartoApiKey,
    this.initialCenter = const LatLng(4.7110, -74.0721), // Bogotá, ajustalo
    this.controller,
    this.onViewFullHistory,
  });

  @override
  State<FamilyMap> createState() => _FamilyMapState();
}

class _FamilyMapState extends State<FamilyMap> {
  String? selectedMemberId;

  MemberLocation? get selectedMember => selectedMemberId == null
      ? null
      : widget.members.firstWhere((m) => m.id == selectedMemberId);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: 13,
            onTap: (_, __) => setState(
              () => selectedMemberId = null,
            ), // tocar el mapa cierra el popup
          ),
          children: [
            ColorFiltered(
              // Tinte cálido muy sutil para que combine con la paleta de la app.
              colorFilter: const ColorFilter.mode(
                Color(0x06B5673A),
                BlendMode.srcATop,
              ),
              child: TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png?key=${widget.cartoApiKey}',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.tuapp.cerca',
              ),
            ),

            MarkerLayer(
              markers: [
                for (final member in widget.members)
                  Marker(
                    point: member.position,
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => setState(
                        () => selectedMemberId = selectedMemberId == member.id
                            ? null
                            : member.id,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: member.color,
                          border: Border.all(
                            color: Colors.white,
                            width: selectedMemberId == member.id ? 4 : 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            member.initials,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Popup con el nombre y último visto, arriba de la barra inferior del scaffold
        if (selectedMember != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _MemberPopup(
              member: selectedMember!,
              onClose: () => setState(() => selectedMemberId = null),
              onViewFullHistory: widget.onViewFullHistory,
            ),
          ),
      ],
    );
  }
}

class _MemberPopup extends StatelessWidget {
  final MemberLocation member;
  final VoidCallback onClose;
  final void Function(MemberLocation member)? onViewFullHistory;

  const _MemberPopup({
    required this.member,
    required this.onClose,
    this.onViewFullHistory,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      borderRadius: BorderRadius.circular(18),
      color: colors.surface,
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: member.color,
              child: Text(
                member.initials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    member.lastSeenText,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (onViewFullHistory != null)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onViewFullHistory!(member),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.history, size: 20, color: colors.selected),
                ),
              ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onClose,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close, size: 18, color: colors.unselected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
