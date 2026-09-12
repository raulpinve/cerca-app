import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

/// Ubicación de un miembro para pintar en el mapa.
class MemberLocation {
  final String initials;
  final LatLng position;
  final Color color;

  const MemberLocation({
    required this.initials,
    required this.position,
    required this.color,
  });
}

class FamilyMap extends StatelessWidget {
  final List<MemberLocation> members;
  final LatLng initialCenter;
  final MapController? controller;

  /// Conseguila gratis (sin cola de aprobación) en:
  /// https://carto.com/basemaps/apikey/
  final String cartoApiKey;

  const FamilyMap({
    super.key,
    required this.members,
    required this.cartoApiKey,
    this.initialCenter = const LatLng(4.7110, -74.0721), // Bogotá, ajustalo
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: 13,
      ),
      children: [
        ColorFiltered(
          // Tinte cálido sutil para que combine con la paleta de la app.
          // Bajá la opacidad del color (el 4to valor del ColorFilter) si lo sentís muy fuerte.
          colorFilter: const ColorFilter.mode(
            Color(
              0x06B5673A,
            ), // antes 0x11 — bajalo más (0x00) o subilo (0x22) a gusto
            BlendMode.srcATop,
          ),
          child: TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png?key=$cartoApiKey',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName:
                'com.tuapp.cerca', // poné tu applicationId real
          ),
        ),
        MarkerLayer(
          markers: [
            for (final member in members)
              Marker(
                point: member.position,
                width: 44,
                height: 44,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: member.color,
                    border: Border.all(color: Colors.white, width: 3),
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
          ],
        ),
      ],
    );
  }
}
