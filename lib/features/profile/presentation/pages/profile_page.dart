import 'dart:convert';

import 'package:app/core/theme/app_colors.dart';
// Ajusta esta ruta a donde tengas tu AppConfig real:
// class AppConfig { static const String apiHost = 'http://10.0.2.2:3000'; }
import 'package:app/core/config/app_config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// MODELOS (mapean a tus tablas users y devices)
// ---------------------------------------------------------------------------

class AppUser {
  final String firstName;
  final String lastName;
  final String email;

  const AppUser({
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  String get fullName => '$firstName $lastName';

  // Mapea la respuesta de GET/PATCH /users/me:
  // { "firstName": "...", "lastName": "...", "email": "..." }
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

class Device {
  final String id;
  final String userId;
  final String deviceName;
  final String platform; // 'ios' | 'android' | etc.
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  const Device({
    required this.id,
    required this.userId,
    required this.deviceName,
    required this.platform,
    required this.isActive,
    this.createdAt,
    this.lastSeenAt,
  });

  // Mapea la respuesta real de tu API:
  // { "id": "...", "userId": "...", "deviceName": "...", "platform": "android",
  //   "isActive": true, "createdAt": "...", "lastSeenAt": null }
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? 'Dispositivo',
      platform: (json['platform'] as String? ?? 'other').toLowerCase(),
      isActive: json['isActive'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.tryParse(json['lastSeenAt'] as String)
          : null,
    );
  }
}

// Obtiene el ID Token vigente de Firebase (se auto-renueva si expiró) y arma
// los headers de auth. Lo usan tanto DeviceRepository como UserRepository.
Future<Map<String, String>> _authHeaders() async {
  final firebaseUser = FirebaseAuth.instance.currentUser;
  if (firebaseUser == null) {
    throw ApiException('No hay una sesión activa.');
  }
  String idToken;
  try {
    idToken = await firebaseUser.getIdToken() ?? '';
  } catch (_) {
    throw ApiException('No se pudo validar tu sesión.');
  }
  if (idToken.isEmpty) {
    throw ApiException('No se pudo validar tu sesión.');
  }
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $idToken',
  };
}

// Toma el body { success, message, data } de tu API y devuelve 'data' tal
// cual (puede ser un Map para /users/me o una List para /devices),
// lanzando ApiException si algo salió mal.
dynamic _unwrap(http.Response response) {
  if (response.statusCode == 401) {
    throw ApiException('Sesión expirada, vuelve a iniciar sesión.');
  }
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException('Error del servidor (${response.statusCode}).');
  }
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (body['success'] != true) {
    throw ApiException(body['message']?.toString() ?? 'Error desconocido.');
  }
  return body['data'];
}

class UserRepository {
  Future<AppUser> fetchMe() async {
    final headers = await _authHeaders();
    late final http.Response response;
    try {
      response = await http.get(
        Uri.parse('${AppConfig.apiHost}/users/me'),
        headers: headers,
      );
    } catch (_) {
      throw ApiException('No hay conexión con el servidor.');
    }
    return AppUser.fromJson(_unwrap(response) as Map<String, dynamic>);
  }

  Future<AppUser> updateMe({
    required String firstName,
    required String lastName,
  }) async {
    final headers = await _authHeaders();
    late final http.Response response;
    try {
      response = await http.patch(
        Uri.parse('${AppConfig.apiHost}/users/me'),
        headers: headers,
        body: jsonEncode({'firstName': firstName, 'lastName': lastName}),
      );
    } catch (_) {
      throw ApiException('No hay conexión con el servidor.');
    }
    return AppUser.fromJson(_unwrap(response) as Map<String, dynamic>);
  }
}

// ---------------------------------------------------------------------------
// REPOSITORIO: trae los dispositivos desde tu API (GET /devices)
// ---------------------------------------------------------------------------

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class DeviceRepository {
  Future<List<Device>> fetchDevices() async {
    final headers = await _authHeaders();
    late final http.Response response;
    try {
      response = await http.get(
        Uri.parse('${AppConfig.apiHost}/devices'),
        headers: headers,
      );
    } catch (_) {
      throw ApiException('No hay conexión con el servidor.');
    }

    final rawList = _unwrap(response) as List<dynamic>? ?? [];
    return rawList
        .map((item) => Device.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

// Traducción legible del tiempo transcurrido, usada por _DeviceTile.
String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'hace un momento';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return 'hace ${diff.inDays} días';
}

// ---------------------------------------------------------------------------
// PANTALLA
// ---------------------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _LoadState { loading, loaded, error }

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  final _deviceRepository = DeviceRepository();
  final _userRepository = UserRepository();

  _LoadState _state = _LoadState.loading;
  List<Device> _devices = [];
  String? _errorMessage;

  _LoadState _userState = _LoadState.loading;
  AppUser? _user;
  String? _userErrorMessage;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _loadUser();
    _loadDevices();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() => _userState = _LoadState.loading);
    try {
      final user = await _userRepository.fetchMe();
      if (!mounted) return;
      setState(() {
        _user = user;
        _userState = _LoadState.loaded;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _userErrorMessage = e.message;
        _userState = _LoadState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userErrorMessage = 'No se pudo cargar tu perfil.';
        _userState = _LoadState.error;
      });
    }
  }

  Future<void> _editName() async {
    if (_user == null) return;
    final colors = context.appColors;
    final firstNameController = TextEditingController(text: _user!.firstName);
    final lastNameController = TextEditingController(text: _user!.lastName);

    InputDecoration fieldDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colors.selected, width: 1.5),
        ),
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Editar perfil',
          style: TextStyle(color: colors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              style: TextStyle(color: colors.textPrimary),
              cursorColor: colors.selected,
              decoration: fieldDecoration('Nombre'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: lastNameController,
              style: TextStyle(color: colors.textPrimary),
              cursorColor: colors.selected,
              decoration: fieldDecoration('Apellido'),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: colors.selected,
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final newFirstName = firstNameController.text.trim();
    final newLastName = lastNameController.text.trim();
    if (newFirstName.isEmpty) return;

    try {
      final updated = await _userRepository.updateMe(
        firstName: newFirstName,
        lastName: newLastName,
      );
      if (!mounted) return;
      setState(() => _user = updated);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el perfil.')),
      );
    }
  }

  Future<void> _loadDevices() async {
    setState(() => _state = _LoadState.loading);
    try {
      final devices = await _deviceRepository.fetchDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _state = _LoadState.loaded;
      });
      _entranceController.forward(from: 0);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _state = _LoadState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Algo salió mal cargando tus dispositivos.';
        _state = _LoadState.error;
      });
    }
  }

  // Interval helper: cada sección entra en un tramo distinto de la animación
  // total, generando el efecto "staggered" (cascada).
  Animation<double> _stagger(double start, double end) {
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([_loadUser(), _loadDevices()]),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _FadeSlideIn(
                animation: _stagger(0.0, 0.6),
                child: _buildUserSection(),
              ),
              const SizedBox(height: 20),
              _FadeSlideIn(
                animation: _stagger(0.1, 0.7),
                child: _SectionLabel('Dispositivos'),
              ),
              _buildDevicesSection(),
              const SizedBox(height: 20),
              _FadeSlideIn(
                animation: _stagger(0.4, 1.0),
                child: _SignOutButton(
                  onTap: () {
                    FlutterBackgroundService().invoke('stopService');
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserSection() {
    final colors = context.appColors;
    switch (_userState) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      case _LoadState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text(
                _userErrorMessage ?? 'No se pudo cargar tu perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: _loadUser, child: const Text('Reintentar')),
            ],
          ),
        );
      case _LoadState.loaded:
        return _UserHeader(user: _user!, onEditTap: _editName);
    }
  }

  Widget _buildDevicesSection() {
    final colors = context.appColors;
    switch (_state) {
      case _LoadState.loading:
        return _SectionCard(
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ],
        );

      case _LoadState.error:
        return _SectionCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              child: Column(
                children: [
                  Text(
                    _errorMessage ?? 'Ocurrió un error.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _loadDevices,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ],
        );

      case _LoadState.loaded:
        if (_devices.isEmpty) {
          return _SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No tienes dispositivos vinculados.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ),
            ],
          );
        }
        return _SectionCard(
          children: [
            for (var i = 0; i < _devices.length; i++)
              _FadeSlideIn(
                // cada dispositivo entra un poco después del anterior
                animation: _stagger(0.2 + i * 0.1, 0.8 + i * 0.1),
                child: _DeviceTile(device: _devices[i]),
              ),
          ],
        );
    }
  }
}

// ---------------------------------------------------------------------------
// WRAPPER DE ENTRADA (fade + slide sutil hacia arriba)
// ---------------------------------------------------------------------------

class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FadeSlideIn({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - animation.value)),
            child: child,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// HEADER DE USUARIO
// ---------------------------------------------------------------------------

class _UserHeader extends StatefulWidget {
  final AppUser user;
  final VoidCallback? onEditTap;
  const _UserHeader({required this.user, this.onEditTap});

  @override
  State<_UserHeader> createState() => _UserHeaderState();
}

class _UserHeaderState extends State<_UserHeader> {
  double _avatarScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final user = widget.user;

    return Column(
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTapDown: (_) => setState(() => _avatarScale = 0.92),
          onTapUp: (_) => setState(() => _avatarScale = 1.0),
          onTapCancel: () => setState(() => _avatarScale = 1.0),
          child: AnimatedScale(
            scale: _avatarScale,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            child: CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFFE9C9A0),
              child: Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B4A26),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.fullName,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color: colors.textPrimary,
              ),
            ),
            if (widget.onEditTap != null) ...[
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: widget.onEditTap,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.edit, size: 15, color: colors.unselected),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TARJETA CONTENEDORA DE SECCIÓN
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colors.textSecondary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colors.indicator.withOpacity(0.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

// ---------------------------------------------------------------------------
// FILA DE DISPOSITIVO
// ---------------------------------------------------------------------------

class _DeviceTile extends StatelessWidget {
  final Device device;
  const _DeviceTile({required this.device});

  IconData get _icon {
    switch (device.platform) {
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      default:
        return Icons.devices_other;
    }
  }

  String get _statusText {
    if (device.isActive) return 'Activo ahora';
    final lastSeen = device.lastSeenAt;
    if (lastSeen == null) return 'Sin actividad registrada';
    return 'Inactivo · ${timeAgo(lastSeen)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {}, // hook para ver detalle del dispositivo si lo necesitas
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(_icon, size: 18, color: colors.unselected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: TextStyle(fontSize: 14, color: colors.textPrimary),
                    ),
                    Text(
                      _statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (device.isActive) const _PulsingDot(),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PUNTO DE ESTADO "ACTIVO" CON PULSO CONTINUO
// ---------------------------------------------------------------------------

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // halo que se expande y se desvanece
            Opacity(
              opacity: (1 - t) * 0.5,
              child: Container(
                width: 8 + 10 * t,
                height: 8 + 10 * t,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF8FAE7C),
                ),
              ),
            ),
            // punto fijo
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF8FAE7C),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// BOTÓN DE CERRAR SESIÓN
// ---------------------------------------------------------------------------

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SignOutButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Cerrar sesión',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFFC15C4A),
            ),
          ),
        ),
      ),
    );
  }
}
