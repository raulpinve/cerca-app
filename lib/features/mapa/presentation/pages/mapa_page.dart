import 'dart:async';

import 'package:app/core/config/app_config.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/features/location/data/repositories/device_repository.dart';
import 'package:app/features/location/data/repositories/location_repository.dart';
import 'package:app/features/location/data/services/location_tracking_service.dart';
import 'package:app/features/location/presentation/pages/location_history_page.dart';
import 'package:app/features/mapa/data/repositories/circle_repository.dart';
import 'package:app/features/mapa/presentation/widgets/circle_selector.dart';
import 'package:app/features/mapa/presentation/widgets/family_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/features/mapa/data/mappers/member_location_mapper.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  List<MemberLocation> _members = [];
  Timer? _refreshTimer;
  final _locationService = LocationTrackingService();
  final _locationRepository = LocationRepository();
  final _deviceRepository = DeviceRepository();
  final _circleRepository = CircleRepository();
  String? _deviceId;

  List<Circle> _circles = [];
  String? activeCircleId;
  bool _isLoadingCircles = true;

  Circle? get activeCircle => _circles.isEmpty
      ? null
      : _circles.firstWhere((c) => c.id == activeCircleId);

  @override
  void initState() {
    super.initState();
    _initDeviceAndTracking();
    _checkPermissionStatus();
    _loadCircles();

    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _loadCircleLocations(),
    );
  }

  Future<void> _loadCircles() async {
    setState(() => _isLoadingCircles = true);

    try {
      final responses = await _circleRepository.getMyCircles();

      final circles = responses
          .map(
            (r) => Circle(
              id: r.id,
              name: r.name,
              memberCount: r.memberCount,
              memberInitials: r.memberInitials,
            ),
          )
          .toList();

      if (mounted) {
        setState(() {
          _circles = circles;
          activeCircleId = circles.isNotEmpty ? circles.first.id : null;
          _isLoadingCircles = false;
        });
      }

      if (activeCircleId != null) {
        await _loadCircleLocations();
      }
    } catch (e) {
      debugPrint('Error cargando círculos: $e');
      if (mounted) setState(() => _isLoadingCircles = false);
    }
  }

  Future<void> _createCircle(String name) async {
    try {
      await _circleRepository.createCircle(name);
      await _loadCircles();
    } catch (e) {
      debugPrint('Error creando círculo: $e');
    }
  }

  Future<void> _showCreateCircleDialog() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo círculo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Ej: Mi familia'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _createCircle(name);
    }
  }

  Future<void> _loadCircleLocations() async {
    if (activeCircleId == null) return;

    debugPrint('Cargando ubicaciones para circleId: $activeCircleId');
    try {
      final responses = await _locationRepository.getCircleLocations(
        activeCircleId!,
      );
      final members = responses.map(toMemberLocation).toList();
      if (mounted) setState(() => _members = members);
    } catch (e) {
      debugPrint('Error cargando ubicaciones del círculo: $e');
    }
  }

  Future<void> _initDeviceAndTracking() async {
    try {
      _deviceId = await _deviceRepository.getOrRegisterDeviceId();
      debugPrint('Device ID: $_deviceId');
    } catch (e) {
      debugPrint('Error registrando dispositivo: $e');
      return; // sin deviceId no arrancamos el tracking
    }

    await _startLocationTracking();
  }

  Future<void> _startLocationTracking() async {
    final started = await _locationService.start(
      onUpdate: _onOwnLocationUpdate,
    );

    debugPrint('¿Tracking iniciado?: $started');

    if (!started && mounted) {
      debugPrint('No se pudieron iniciar los permisos de ubicación');
    }
  }

  void _onOwnLocationUpdate(Position position) async {
    if (_deviceId == null) return;

    await _locationRepository.updateMyLocation(
      deviceId: _deviceId!,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
    );

    debugPrint('Enviado: ${position.latitude}, ${position.longitude}');
  }

  Future<void> _checkPermissionStatus() async {
    final permission = await Geolocator.checkPermission();
    debugPrint('Permiso actual: $permission');
  }

  @override
  void dispose() {
    _locationService.stop();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_isLoadingCircles) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_circles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No tienes círculos todavía.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _showCreateCircleDialog,
                child: const Text('Crear mi primer círculo'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FamilyMap(
          members: _members,
          cartoApiKey: AppConfig.cartoApiKey,
          onViewFullHistory: (member) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => LocationHistoryPage(
                  memberName: member.name,
                  initials: member.initials,
                  color: member.color,
                  points: [
                    LocationPoint(
                      latitude: 4.7110,
                      longitude: -74.0721,
                      recordedAt: DateTime.now().subtract(
                        const Duration(hours: 6),
                      ),
                    ),
                    LocationPoint(
                      latitude: 4.7080,
                      longitude: -74.0700,
                      recordedAt: DateTime.now().subtract(
                        const Duration(hours: 5, minutes: 15),
                      ),
                    ),
                    LocationPoint(
                      latitude: 4.7050,
                      longitude: -74.0650,
                      recordedAt: DateTime.now().subtract(
                        const Duration(hours: 5),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleChip(
                  circle: activeCircle!,
                  onTap: () => showCircleSelector(
                    context,
                    circles: _circles,
                    activeCircleId: activeCircleId!,
                    onCircleSelected: (id) {
                      setState(() {
                        activeCircleId = id;
                        _members = [];
                      });
                      _loadCircleLocations();
                    },
                  ),
                ),
                Row(
                  children: [
                    CircleIconButton(
                      icon: Icons.add,
                      onTap: _showCreateCircleDialog,
                    ),
                    const SizedBox(width: 8),
                    CircleIconButton(
                      icon: Icons.notifications_outlined,
                      onTap: () {
                        // navegar a Invitaciones
                      },
                    ),
                  ],
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
