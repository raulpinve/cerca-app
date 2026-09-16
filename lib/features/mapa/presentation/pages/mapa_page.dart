import 'dart:async';

import 'package:app/core/config/app_config.dart';
import 'package:app/core/services/app_location_controller.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/features/invitations/data/repositories/invitation_repository.dart';
import 'package:app/features/location/data/repositories/location_repository.dart';
import 'package:app/features/location/data/services/socket_service.dart';
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

class _MapaPageState extends State<MapaPage> with WidgetsBindingObserver {
  List<MemberLocation> _members = [];
  StreamSubscription<Position>? _positionSub;
  final _locationRepository = LocationRepository();
  final _circleRepository = CircleRepository();
  final _mapController = MapController();
  final _invitationRepository = InvitationRepository();
  LocationPermission? _permissionStatus;
  final _socketService = SocketService();
  bool _hasCenteredOnce = false;
  String? _currentUserId;

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
    WidgetsBinding.instance.addObserver(this);
    _checkPermissionStatus();
    _loadCurrentUser();
    _loadCircles();
    _connectSocket();
    _positionSub = AppLocationController.instance.positionStream.listen(
      _updateOwnMemberLocally,
    );
  }

  Future<void> _loadCurrentUser() async {
    try {
      final userId = await _locationRepository.getMyUserId();

      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
      }
    } catch (e) {
      debugPrint('Error obteniendo usuario actual: $e');
    }
  }

  Future<void> _connectSocket() async {
    await _socketService.connect(
      onLocationUpdate: _onRemoteLocationUpdate,
    );
  }

  void _onRemoteLocationUpdate(Map<String, dynamic> data) {
    final userId = data['userId'] as String;

    final index = _members.indexWhere(
      (m) => m.userId == userId,
    );

    if (index == -1) return;

    final updated = MemberLocation(
      id: _members[index].id,
      userId: _members[index].userId,
      name: _members[index].name,
      initials: _members[index].initials,
      position: LatLng(
        (data['latitude'] as num).toDouble(),
        (data['longitude'] as num).toDouble(),
      ),
      color: _members[index].color,
      lastSeenText: 'En vivo',
      recentTrail: _members[index].recentTrail,
    );

    if (mounted) {
      setState(() {
        _members = [
          ..._members.sublist(0, index),
          updated,
          ..._members.sublist(index + 1),
        ];
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _socketService.disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
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
              role: r.role,
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

  void _centerOnMyLocation() {
    if (_members.isEmpty) return;

    final myMember = _members.firstWhere(
      (m) => m.userId == _currentUserId,
      orElse: () => _members.first,
    );

    try {
      _mapController.move(myMember.position, 15);
    } catch (e) {
      debugPrint('No se pudo centrar: aún no hay tu ubicación cargada');
    }
  }

  void _updateOwnMemberLocally(Position position) {
    if (!mounted) return;

    final index = _members.indexWhere(
      (m) => m.userId == _currentUserId,
    );
    if (index == -1) return;

    final updated = MemberLocation(
      id: _members[index].id,
      userId: _members[index].userId,
      name: _members[index].name,
      initials: _members[index].initials,
      position: LatLng(position.latitude, position.longitude),
      color: _members[index].color,
      lastSeenText: 'En vivo',
      recentTrail: _members[index].recentTrail,
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
    if (mounted) {
      setState(() => _permissionStatus = permission);
    }
  }

  Future<void> _showInviteDialog() async {
    final controller = TextEditingController();
    final colors = context.appColors;

    if (activeCircleId == null) return;

    final email = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invitar a ${activeCircle?.name ?? "este círculo"}',
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
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Correo electrónico',
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
                        'Invitar',
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

    if (email != null && email.isNotEmpty) {
      await _sendInvitation(email);
    }
  }

  Future<void> _sendInvitation(String email) async {
    try {
      await _invitationRepository.createInvitation(
        circleId: activeCircleId!,
        email: email,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invitación enviada a $email')),
        );
      }
    } catch (e) {
      debugPrint('Error enviando invitación: $e');
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
          ),
        );
      }
    }
  }

  Future<void> _showLeaveOrDeleteDialog(Circle circle) async {
    final colors = context.appColors;
    final isOwner = circle.isOwner;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOwner
                    ? 'Eliminar "${circle.name}"'
                    : 'Salir de "${circle.name}"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isOwner
                    ? 'Esto elimina el círculo para todos los miembros. No se puede deshacer.'
                    : '¿Seguro que quieres salir de este círculo?',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      'Cancelar',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOwner ? 'Eliminar' : 'Salir',
                        style: const TextStyle(
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

    if (confirmed == true) {
      await _leaveOrDeleteCircle(circle);
    }
  }

  Future<void> _leaveOrDeleteCircle(Circle circle) async {
    try {
      if (circle.isOwner) {
        await _circleRepository.deleteCircle(circle.id);
      } else {
        await _circleRepository.leaveCircle(circle.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              circle.isOwner ? 'Círculo eliminado' : 'Saliste del círculo',
            ),
          ),
        );
      }

      await _loadCircles();
    } catch (e) {
      debugPrint('Error al salir/eliminar círculo: $e');
      if (mounted) {
        final message = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  // Métodos para zoom, junto a _centerOnMyLocation
  void _zoomIn() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom + 1);
  }

  void _zoomOut() {
    final camera = _mapController.camera;
    _mapController.move(camera.center, camera.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final topInset = MediaQuery.of(context).padding.top;

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

    if (_currentUserId == null) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.selected,
        ),
      );
    }

    return Stack(
      children: [
        FamilyMap(
          members: _members,
          cartoApiKey: AppConfig.cartoApiKey,
          controller: _mapController,
          currentUserId: _currentUserId!,
          onViewFullHistory: (member) async {
            try {
              final points = await _locationRepository.getUserHistory(
                member.userId,
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No se pudo cargar el historial de este miembro',
                    ),
                  ),
                );
              }
            }
          },
        ),

        Positioned(
          right: 16,
          bottom: 150,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleIconButton(
                icon: Icons.add,
                onTap: _zoomIn,
                size: 40,
              ),
              const SizedBox(height: 8),
              CircleIconButton(
                icon: Icons.remove,
                onTap: _zoomOut,
                size: 40,
              ),
              const SizedBox(height: 8),
              CircleIconButton(
                icon: Icons.my_location,
                onTap: _members.isNotEmpty ? _centerOnMyLocation : null,
                size: 46,
              ),
            ],
          ),
        ),

        if (_isLoadingLocations)
          Positioned(
            top: topInset + 70,
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
            top: topInset + 70,
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

        if (_permissionStatus == LocationPermission.denied ||
            _permissionStatus == LocationPermission.deniedForever)
          Positioned(
            top: topInset + 130,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_off,
                          color: Colors.orange.shade800,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sin permiso de ubicación. Actívalo en Ajustes para que tu familia pueda verte',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Geolocator.openAppSettings(),
                        child: Text(
                          'Ir a Ajustes',
                          style: TextStyle(color: Colors.orange.shade900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_permissionStatus == LocationPermission.whileInUse)
          Positioned(
            top: topInset + 70,
            left: 16,
            right: 16,
            child: Material(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Actívalo también en segundo plano para no perder tu ubicación',
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: Text(
                        'Ajustes',
                        style: TextStyle(color: Colors.blue.shade900),
                      ),
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
                    onLongPressCircle: _showLeaveOrDeleteDialog,
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
                      icon: Icons.person_add_outlined,
                      onTap: activeCircleId != null ? _showInviteDialog : null,
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
