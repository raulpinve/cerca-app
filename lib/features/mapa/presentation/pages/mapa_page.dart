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
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/features/mapa/data/mappers/member_location_mapper.dart';
import 'package:latlong2/latlong.dart' show LatLng;

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
  final _mapController = MapController();

  bool _hasCenteredOnce = false;
  String? _deviceId;

  List<Circle> _circles = [];
  String? activeCircleId;
  bool _isLoadingCircles = true;
  bool _isLoadingLocations = false;
  String? _locationsError;

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
      (_) => _loadCircleLocations(
        showLoading: false,
      ),
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
    final colors = context.appColors;

    final name = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nuevo círculo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Ej: Mi familia',
                  hintStyle: TextStyle(color: colors.textSecondary),
                  filled: true,
                  fillColor: colors.indicator,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, controller.text.trim()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: colors.selected,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Crear',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (name != null && name.isNotEmpty) {
      await _createCircle(name);
    }
  }

  Future<void> _loadCircleLocations({bool showLoading = true}) async {
    if (activeCircleId == null) return;

    debugPrint('Cargando ubicaciones para circleId: $activeCircleId');

    if (showLoading) {
      setState(() {
        _isLoadingLocations = true;
        _locationsError = null;
      });
    }

    try {
      final responses = await _locationRepository.getCircleLocations(
        activeCircleId!,
      );
      final members = responses.map(toMemberLocation).toList();

      if (mounted) {
        setState(() {
          _members = members;
          _isLoadingLocations = false;
          _locationsError = null;
        });

        // Centra automáticamente solo la primera vez que cargan datos
        if (!_hasCenteredOnce && _members.isNotEmpty) {
          _hasCenteredOnce = true;
          _centerOnMyLocation();
        }
      }
    } catch (e) {
      debugPrint('Error cargando ubicaciones del círculo: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
          if (showLoading) {
            _locationsError = 'No se pudieron cargar las ubicaciones';
          }
        });
      }
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

  void _centerOnMyLocation() {
    if (_deviceId == null) return;

    final myMember = _members.firstWhere(
      (m) => m.deviceId == _deviceId,
      orElse: () => _members.isNotEmpty
          ? _members.first
          : throw Exception('Sin miembros'),
    );

    try {
      _mapController.move(myMember.position, 15);
    } catch (e) {
      debugPrint('No se pudo centrar: aún no hay tu ubicación cargada');
    }
  }

  void _onOwnLocationUpdate(Position position) async {
    if (_deviceId == null) return;

    // 1. Actualiza tu propio pin de inmediato, sin esperar al backend
    _updateOwnMemberLocally(position);

    // 2. Envía al backend (para que los demás te vean, y quede en el historial)
    await _locationRepository.updateMyLocation(
      deviceId: _deviceId!,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyM: position.accuracy,
    );

    debugPrint('Enviado: ${position.latitude}, ${position.longitude}');
  }

  void _updateOwnMemberLocally(Position position) {
    if (!mounted) return;

    final index = _members.indexWhere((m) => m.deviceId == _deviceId);
    if (index == -1) return; // aún no tenemos tu propio member cargado del backend, ignora por ahora

    final updated = MemberLocation(
      id: _members[index].id,
      deviceId: _members[index].deviceId,
      name: _members[index].name,
      initials: _members[index].initials,
      position: LatLng(position.latitude, position.longitude),
      color: _members[index].color,
      lastSeenText: 'En vivo',
      recentTrail:
          _members[index].recentTrail, // el trail sigue viniendo del backend
    );

    setState(() {
      _members = [
        ..._members.sublist(0, index),
        updated,
        ..._members.sublist(index + 1),
      ];
    });
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
      return Center(
        child: CircularProgressIndicator(color: colors.selected),
      );
    }

    if (_circles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No tienes círculos todavía.',
                style: TextStyle(color: colors.textPrimary),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _showCreateCircleDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.selected,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Crear mi primer círculo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
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
          controller: _mapController,
          onViewFullHistory: (member) async {
            try {
              final points = await _locationRepository.getDeviceHistory(
                member.deviceId,
              );

              if (!mounted) return;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LocationHistoryPage(
                    memberName: member.name,
                    initials: member.initials,
                    color: member.color,
                    cartoApiKey: AppConfig.cartoApiKey,
                    points: points.reversed
                        .map(
                          (p) => LocationPoint(
                            latitude: p.latitude,
                            longitude: p.longitude,
                            recordedAt: p.recordedAt,
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            } catch (e) {
              debugPrint('Error cargando historial: $e');
            }
          },
        ),
        if (_isLoadingLocations)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colors.selected,
                ),
              ),
            ),
          ),

        if (_locationsError != null)
          Positioned(
            top: 80,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationsError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () => _loadCircleLocations(),
                    ),
                  ],
                ),
              ),
            ),
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
                    onCreateCircle: _showCreateCircleDialog,
                    onCircleSelected: (id) {
                      setState(() {
                        activeCircleId = id;
                        _members = [];
                      });
                      _loadCircleLocations();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _centerOnMyLocation,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(Icons.my_location, color: colors.selected),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
