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

  /// No hay dispositivo vinculado. El registro normal ocurre en el
  /// login; si llegamos acá es porque ese registro falló o el device
  /// fue desvinculado después (ej. lo borraron desde otra sesión).
  notLinked,
}

/// IMPORTANTE: este controller ya NO crea dispositivos por sí solo
/// durante el tracking. El registro "feliz" ocurre en el login
/// (DeviceRepository.registerDeviceOnLogin()). Acá solo se CONSUME
/// un deviceId, salvo en relinkDevice(), que es el camino explícito
/// de recuperación cuando el usuario aprieta el botón de la UI.
class AppLocationController {
  AppLocationController._internal();
  static final AppLocationController instance =
      AppLocationController._internal();

  final _locationService = LocationTrackingService();
  final _locationRepository = LocationRepository();
  final _deviceRepository = DeviceRepository();

  String? deviceId;
  bool _isRunning = false;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  final ValueNotifier<DeviceLinkStatus> deviceLinkStatus = ValueNotifier(
    DeviceLinkStatus.checking,
  );

  bool get isRunning => _isRunning;

  Future<bool>? _startFuture;

  Future<bool> start() async {
    if (_isRunning) return true;
    if (_startFuture != null) return _startFuture!;

    final completer = Completer<bool>();
    _startFuture = completer.future;

    try {
      final result = await _startInternal();
      completer.complete(result);
      return result;
    } finally {
      _startFuture = null;
    }
  }

  /// Se llama justo después de un login exitoso.
  Future<bool> registerDeviceOnLogin() => _registerAndStartTracking();

  /// Se llama desde el botón "Vincular este dispositivo" cuando el
  /// registro automático falló o el device fue desvinculado después.
  /// Es el mismo flujo que el login: idempotente, no duplica.
  Future<bool> relinkDevice() => _registerAndStartTracking();

  Future<bool> _registerAndStartTracking() async {
    stop();
    deviceLinkStatus.value = DeviceLinkStatus.checking;

    try {
      deviceId = await _deviceRepository.registerDeviceOnLogin();
    } on AuthenticationException catch (e) {
      debugPrint('Error de autenticación al vincular: $e');
      deviceLinkStatus.value = DeviceLinkStatus.authError;
      return false;
    } catch (e) {
      debugPrint('Error vinculando dispositivo: $e');
      deviceLinkStatus.value = DeviceLinkStatus.notLinked;
      return false;
    }

    deviceLinkStatus.value = DeviceLinkStatus.linked;

    final started = await _locationService.start(onUpdate: _onPositionUpdate);
    _isRunning = started;
    debugPrint('¿Tracking iniciado?: $started');
    return started;
  }

  Future<bool> _startInternal() async {
    deviceLinkStatus.value = DeviceLinkStatus.checking;

    deviceId = await _deviceRepository.getSavedDeviceId();

    if (deviceId == null) {
      debugPrint('No hay device vinculado, no se puede iniciar tracking');
      deviceLinkStatus.value = DeviceLinkStatus.notLinked;
      return false;
    }

    deviceLinkStatus.value = DeviceLinkStatus.linked;

    final started = await _locationService.start(onUpdate: _onPositionUpdate);
    _isRunning = started;
    debugPrint('¿Tracking global iniciado?: $started');
    return started;
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
      // El backend ya no reconoce este device (fue eliminado o
      // desactivado desde otro lado). Ya no re-registramos solos acá
      // para no reabrir la puerta a duplicados fuera de login/relink;
      // avisamos a la UI y el usuario usa el botón de relink.
      deviceLinkStatus.value = DeviceLinkStatus.notLinked;
      _isRunning = false;
      _locationService.stop();
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
