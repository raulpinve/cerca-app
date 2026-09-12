import 'package:app/core/config/app_config.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/features/mapa/presentation/widgets/circle_selector.dart';
import 'package:app/features/mapa/presentation/widgets/family_map.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' show LatLng;

// Datos de ejemplo. Después esto viene de tu CircleRepository / provider.
final circles = <Circle>[
  const Circle(
    id: '1',
    name: 'Familia Gomez',
    memberCount: 4,
    memberInitials: ['MA', 'PA', 'SO'],
  ),
  const Circle(
    id: '2',
    name: 'Amigos del asado',
    memberCount: 3,
    memberInitials: ['LU', 'TI'],
  ),
];

// Ubicaciones de ejemplo. Después esto viene de current_locations vía tu repo/websocket.
final sampleMembers = <MemberLocation>[
  const MemberLocation(
    initials: 'MA',
    position: LatLng(4.7110, -74.0721),
    color: Color(0xFFE9C9A0),
  ),
  const MemberLocation(
    initials: 'PA',
    position: LatLng(4.7050, -74.0650),
    color: Color(0xFFC9AEDD),
  ),
  const MemberLocation(
    initials: 'SO',
    position: LatLng(4.7180, -74.0600),
    color: Color(0xFFE9A0A0),
  ),
];

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  String activeCircleId = circles.first.id;

  Circle get activeCircle => circles.firstWhere((c) => c.id == activeCircleId);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Stack(
      children: [
        FamilyMap(
          members: sampleMembers,
          cartoApiKey: AppConfig
              .cartoApiKey, // pegá la que te dé carto.com/basemaps/apikey
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleChip(
                  circle: activeCircle,
                  onTap: () => showCircleSelector(
                    context,
                    circles: circles,
                    activeCircleId: activeCircleId,
                    onCircleSelected: (id) =>
                        setState(() => activeCircleId = id),
                  ),
                ),
                CircleIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: () {
                    // navegar a Invitaciones
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;

  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 38,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      borderRadius: BorderRadius.circular(size / 2),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
          ],
        ),
        child: Icon(icon, size: size * 0.47, color: colors.unselected),
      ),
    );
  }
}
