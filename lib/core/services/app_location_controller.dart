import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/features/location/data/repositories/device_repository.dart';
import 'package:app/features/location/data/repositories/location_repository.dart';
import 'package:app/features/location/data/services/location_tracking_service.dart';

enum DeviceLinkStatus {
  /// Aún no sabemos el estado (arrancando la app).
  checking,

  /// Dispositivo vinculado y funcionando.
  linked,

  /// No hay sesión válida; hay que volver a loguearse.
  authError,

  /// Hay sesión pero el dispositivo no está vinculado (fue eliminado,
  /// falló el registro, etc.). El usuario debe re-vincularlo.
  notLinked,
}

class AppLocationController {
  AppLocationController._internal();
  static final AppLocationController instance =
      AppLocationController._internal();

  final _locationService = LocationTrackingService();
  final _locationRepository = LocationRepository();
  final _deviceRepository = DeviceRepository();

  String? deviceId;
  bool _isRunning = false;
  bool _isReregisteringDevice = false;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  /// Estado de vinculación, observable por la UI (ValueListenableBuilder).
  /// Usamos ValueNotifier en vez de Stream para tener acceso síncrono
  /// al valor actual desde el primer build (sin esperar el primer evento).
  final ValueNotifier<DeviceLinkStatus> deviceLinkStatus = ValueNotifier(
    DeviceLinkStatus.checking,
  );

  bool get isRunning => _isRunning;

  Future<bool> start() async {
    if (_isRunning) return true;

    deviceLinkStatus.value = DeviceLinkStatus.checking;

    try {
      deviceId = await _deviceRepository.getOrRegisterDeviceId();
    } on AuthenticationException catch (e) {
      debugPrint('Error de autenticación: $e');
      deviceLinkStatus.value = DeviceLinkStatus.authError;
      return false;
    } catch (e) {
      debugPrint('Error registrando dispositivo: $e');
      deviceLinkStatus.value = DeviceLinkStatus.notLinked;
      return false;
    }

    deviceLinkStatus.value = DeviceLinkStatus.linked;

    final started = await _locationService.start(onUpdate: _onPositionUpdate);
    _isRunning = started;
    debugPrint('¿Tracking global iniciado?: $started');
    return started;
  }

  /// Llamado explícitamente desde el botón "Vincular dispositivo".
  /// Fuerza limpiar cualquier id viejo y registrar uno nuevo.
  Future<bool> relinkDevice() async {
    stop();
    deviceId = null;
    await _deviceRepository.clearSavedDeviceId();
    return start();
  }

  void stop() {
    _locationService.stop();
    _isRunning = false;
  }

  void _onPositionUpdate(Position position) async {
    _positionController.add(position);

    if (deviceId == null) return;

    try {
      await _locationRepository.updateMyLocation(
        deviceId: deviceId!,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
      );
      debugPrint('Enviado: ${position.latitude}, ${position.longitude}');
    } on DeviceNotFoundException {
      // Avisamos a la UI de inmediato: hay una ventana en que el
      // dispositivo NO está vinculado, aunque logremos recuperarlo después.
      deviceLinkStatus.value = DeviceLinkStatus.notLinked;

      if (_isReregisteringDevice) return;
      _isReregisteringDevice = true;
      try {
        debugPrint('Device no reconocido por backend, re-registrando...');
        await _deviceRepository.clearSavedDeviceId();
        deviceId = await _deviceRepository.getOrRegisterDeviceId();
        await _locationRepository.updateMyLocation(
          deviceId: deviceId!,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyM: position.accuracy,
        );
        deviceLinkStatus.value = DeviceLinkStatus.linked; // se recuperó solo
      } catch (e) {
        debugPrint('Error al re-registrar dispositivo: $e');
        deviceLinkStatus.value = DeviceLinkStatus.notLinked; // sigue roto
      } finally {
        _isReregisteringDevice = false;
      }
    } catch (e) {
      debugPrint('Error inesperado al enviar ubicación: $e');
    }
  }

  void dispose() {
    stop();
    _positionController.close();
    deviceLinkStatus.dispose();
  }
}
