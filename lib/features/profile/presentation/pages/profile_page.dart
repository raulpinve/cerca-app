import 'dart:convert';

import 'package:app/core/config/app_config.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------------------------
// MODELO DE USUARIO
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
      '${firstName.isNotEmpty ? firstName[0] : ''}'
              '${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  String get fullName => '$firstName $lastName';

  // Mapea la respuesta de GET/PATCH /users/me:
  // {
  //   "firstName": "...",
  //   "lastName": "...",
  //   "email": "..."
  // }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

// ---------------------------------------------------------------------------
// AUTENTICACIÓN / API
// ---------------------------------------------------------------------------

// Obtiene el ID Token vigente de Firebase y arma los headers de auth.

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

// Toma el body:
//
// {
//   "success": true,
//   "message": "...",
//   "data": {...}
// }
//
// y devuelve únicamente data.

dynamic _unwrap(http.Response response) {
  if (response.statusCode == 401) {
    throw ApiException(
      'Sesión expirada, vuelve a iniciar sesión.',
    );
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw ApiException(
      'Error del servidor (${response.statusCode}).',
    );
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;

  if (body['success'] != true) {
    throw ApiException(
      body['message']?.toString() ?? 'Error desconocido.',
    );
  }

  return body['data'];
}

// ---------------------------------------------------------------------------
// EXCEPCIÓN DE API
// ---------------------------------------------------------------------------

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// REPOSITORIO DE USUARIO
// ---------------------------------------------------------------------------

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
      throw ApiException(
        'No hay conexión con el servidor.',
      );
    }

    return AppUser.fromJson(
      _unwrap(response) as Map<String, dynamic>,
    );
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
        body: jsonEncode({
          'firstName': firstName,
          'lastName': lastName,
        }),
      );
    } catch (_) {
      throw ApiException(
        'No hay conexión con el servidor.',
      );
    }

    return AppUser.fromJson(
      _unwrap(response) as Map<String, dynamic>,
    );
  }
}

// ---------------------------------------------------------------------------
// PANTALLA DE PERFIL
// ---------------------------------------------------------------------------

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

enum _LoadState {
  loading,
  loaded,
  error,
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  final _userRepository = UserRepository();

  _LoadState _userState = _LoadState.loading;

  AppUser? _user;

  String? _userErrorMessage;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 700,
      ),
    );

    _loadUser();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // CARGAR USUARIO
  // -------------------------------------------------------------------------

  Future<void> _loadUser() async {
    setState(() {
      _userState = _LoadState.loading;
    });

    try {
      final user = await _userRepository.fetchMe();

      if (!mounted) return;

      setState(() {
        _user = user;
        _userState = _LoadState.loaded;
      });

      _entranceController.forward(
        from: 0,
      );
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

  // -------------------------------------------------------------------------
  // EDITAR NOMBRE
  // -------------------------------------------------------------------------

  Future<void> _editName() async {
    if (_user == null) return;

    final colors = context.appColors;

    final firstNameController = TextEditingController(
      text: _user!.firstName,
    );

    final lastNameController = TextEditingController(
      text: _user!.lastName,
    );

    InputDecoration fieldDecoration(String label) {
      return InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: colors.textSecondary,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: colors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: colors.selected,
            width: 1.5,
          ),
        ),
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Editar perfil',
            style: TextStyle(
              color: colors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                style: TextStyle(
                  color: colors.textPrimary,
                ),
                cursorColor: colors.selected,
                decoration: fieldDecoration(
                  'Nombre',
                ),
                textCapitalization: TextCapitalization.words,
              ),

              const SizedBox(height: 8),

              TextField(
                controller: lastNameController,
                style: TextStyle(
                  color: colors.textPrimary,
                ),
                cursorColor: colors.selected,
                decoration: fieldDecoration(
                  'Apellido',
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
              ),
              child: const Text(
                'Cancelar',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: colors.selected,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Guardar',
              ),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    final newFirstName = firstNameController.text.trim();

    final newLastName = lastNameController.text.trim();

    firstNameController.dispose();
    lastNameController.dispose();

    if (newFirstName.isEmpty) return;

    try {
      final updated = await _userRepository.updateMe(
        firstName: newFirstName,
        lastName: newLastName,
      );

      if (!mounted) return;

      setState(() {
        _user = updated;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo actualizar el perfil.',
          ),
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // CERRAR SESIÓN
  // -------------------------------------------------------------------------

  Future<void> _confirmSignOut() async {
    final colors = context.appColors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            '¿Cerrar sesión?',
            style: TextStyle(
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            'Tendrás que volver a iniciar sesión para usar la app.',
            style: TextStyle(
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
              ),
              child: const Text(
                'Cancelar',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC15C4A),
              ),
              child: const Text(
                'Cerrar sesión',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _signOut();
    }
  }

  Future<void> _signOut() async {
    try {
      FlutterBackgroundService().invoke('stopService');
    } catch (_) {
      // El servicio puede no estar ejecutándose.
    }

    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Puede no existir una sesión activa de Google.
    }

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // FirebaseAuth manejará el estado de sesión.
    }
  }

  // -------------------------------------------------------------------------
  // ANIMACIÓN STAGGERED
  // -------------------------------------------------------------------------

  Animation<double> _stagger(
    double start,
    double end,
  ) {
    return CurvedAnimation(
      parent: _entranceController,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUser,
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _FadeSlideIn(
                animation: _stagger(
                  0.0,
                  0.6,
                ),
                child: _buildUserSection(),
              ),

              const SizedBox(height: 20),

              _FadeSlideIn(
                animation: _stagger(
                  0.4,
                  1.0,
                ),
                child: _SignOutButton(
                  onTap: _confirmSignOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // SECCIÓN USUARIO
  // -------------------------------------------------------------------------

  Widget _buildUserSection() {
    final colors = context.appColors;

    switch (_userState) {
      case _LoadState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 24,
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
        );

      case _LoadState.error:
        return Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
          ),
          child: Column(
            children: [
              Text(
                _userErrorMessage ?? 'No se pudo cargar tu perfil.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                ),
              ),

              const SizedBox(height: 8),

              TextButton(
                onPressed: _loadUser,
                child: const Text(
                  'Reintentar',
                ),
              ),
            ],
          ),
        );

      case _LoadState.loaded:
        return _UserHeader(
          user: _user!,
          onEditTap: _editName,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// WRAPPER DE ENTRADA
// ---------------------------------------------------------------------------

class _FadeSlideIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _FadeSlideIn({
    required this.animation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(
            0.0,
            1.0,
          ),
          child: Transform.translate(
            offset: Offset(
              0,
              14 * (1 - animation.value),
            ),
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

  const _UserHeader({
    required this.user,
    this.onEditTap,
  });

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
          onTapDown: (_) {
            setState(() {
              _avatarScale = 0.92;
            });
          },
          onTapUp: (_) {
            setState(() {
              _avatarScale = 1.0;
            });
          },
          onTapCancel: () {
            setState(() {
              _avatarScale = 1.0;
            });
          },
          child: AnimatedScale(
            scale: _avatarScale,
            duration: const Duration(
              milliseconds: 150,
            ),
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
                  child: Icon(
                    Icons.edit,
                    size: 15,
                    color: colors.unselected,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 2),

        Text(
          user.email,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// BOTÓN CERRAR SESIÓN
// ---------------------------------------------------------------------------

class _SignOutButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SignOutButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(
            vertical: 12,
          ),
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
