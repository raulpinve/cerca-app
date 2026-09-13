import 'package:app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

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
}

class Device {
  final String id;
  final String deviceName;
  final String platform; // 'ios' | 'android' | etc.
  final bool isActive;
  final DateTime? lastSeenAt;

  const Device({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.isActive,
    this.lastSeenAt,
  });
}

// Datos de ejemplo. Después esto viene de tu UserRepository / DeviceRepository.
const sampleUser = AppUser(
  firstName: 'María',
  lastName: 'Gomez',
  email: 'maria.gomez@email.com',
);

final sampleDevices = <Device>[
  Device(
    id: '1',
    deviceName: 'iPhone de María',
    platform: 'ios',
    isActive: true,
    lastSeenAt: DateTime.now().subtract(const Duration(minutes: 2)),
  ),
  Device(
    id: '2',
    deviceName: 'iPad',
    platform: 'ios',
    isActive: false,
    lastSeenAt: DateTime.now().subtract(const Duration(days: 3)),
  ),
];

// ---------------------------------------------------------------------------
// PANTALLA
// ---------------------------------------------------------------------------

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _UserHeader(user: sampleUser),
            const SizedBox(height: 20),
            _SectionLabel('Dispositivos'),
            _SectionCard(
              children: [
                for (final device in sampleDevices) _DeviceTile(device: device),
              ],
            ),
            const SizedBox(height: 20),
            _SignOutButton(
              onTap: () {
                // TODO: cerrar sesión con Firebase Auth y volver a /login
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// HEADER DE USUARIO
// ---------------------------------------------------------------------------

class _UserHeader extends StatelessWidget {
  final AppUser user;
  const _UserHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Column(
      children: [
        const SizedBox(height: 8),
        CircleAvatar(
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
        const SizedBox(height: 10),
        Text(
          user.fullName,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: colors.textPrimary,
          ),
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
    if (device.isActive) return 'Activo · hace 2 min';
    final lastSeen = device.lastSeenAt;
    if (lastSeen == null) return 'Inactivo';
    final days = DateTime.now().difference(lastSeen).inDays;
    return 'Inactivo · hace $days días';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
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
                  style: TextStyle(fontSize: 12, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          if (device.isActive)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF8FAE7C),
              ),
            ),
        ],
      ),
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
    return InkWell(
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
    );
  }
}
