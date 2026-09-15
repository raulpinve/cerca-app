import 'package:app/core/services/app_location_controller.dart';
import 'package:flutter/material.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/features/auth/presentation/pages/login.dart';

class DeviceLinkGate extends StatefulWidget {
  final Widget child;
  const DeviceLinkGate({super.key, required this.child});

  @override
  State<DeviceLinkGate> createState() => _DeviceLinkGateState();
}

class _DeviceLinkGateState extends State<DeviceLinkGate> {
  @override
  void initState() {
    super.initState();
    // Dispara la verificación al montar el gate (una sola vez por sesión
    // de la app; start() ya es idempotente si ya estaba corriendo).
    AppLocationController.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DeviceLinkStatus>(
      valueListenable: AppLocationController.instance.deviceLinkStatus,
      builder: (context, status, _) {
        switch (status) {
          case DeviceLinkStatus.checking:
            return const _CheckingScreen();
          case DeviceLinkStatus.authError:
            return const LoginPage();
          case DeviceLinkStatus.notLinked:
            return const DeviceNotLinkedScreen();
          case DeviceLinkStatus.linked:
            return widget.child;
        }
      },
    );
  }
}

class _CheckingScreen extends StatelessWidget {
  const _CheckingScreen();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class DeviceNotLinkedScreen extends StatefulWidget {
  const DeviceNotLinkedScreen({super.key});

  @override
  State<DeviceNotLinkedScreen> createState() => _DeviceNotLinkedScreenState();
}

class _DeviceNotLinkedScreenState extends State<DeviceNotLinkedScreen> {
  bool _linking = false;
  String? _errorMessage;

  Future<void> _handleRelink() async {
    setState(() {
      _linking = true;
      _errorMessage = null;
    });

    final ok = await AppLocationController.instance.relinkDevice();

    if (!mounted) return;
    setState(() => _linking = false);

    if (!ok) {
      setState(() {
        _errorMessage =
            'No se pudo vincular el dispositivo. '
            'Verifica tu conexión e inténtalo de nuevo.';
      });
    }
    // Si ok == true, el ValueNotifier ya cambió a `linked` y el
    // DeviceLinkGate reconstruye solo, mostrando la app normal.
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phonelink_erase_outlined,
                  size: 56,
                  color: colors.textSecondary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Dispositivo no vinculado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Este dispositivo ya no está conectado a tu cuenta, '
                  'por eso no se está registrando tu ubicación.',
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _linking ? null : _handleRelink,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.selected,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _linking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Vincular este dispositivo'),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFC15C4A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
