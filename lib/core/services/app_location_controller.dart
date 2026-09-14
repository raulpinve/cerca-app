import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app/features/location/data/repositories/device_repository.dart';
import 'package:app/features/location/data/repositories/location_repository.dart';
import 'package:app/features/location/data/services/location_tracking_service.dart';

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

  bool get isRunning => _isRunning;

  Future<bool> start() async {
    if (_isRunning) return true;

    try {
      deviceId = await _deviceRepository.getOrRegisterDeviceId();
    } catch (e) {
      debugPrint('Error registrando dispositivo: $e');
      return false;
    }

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
    // Notifica a quien esté escuchando (ej: MapaPage para tu pin local)
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
      } catch (e) {
        debugPrint('Error al re-registrar dispositivo: $e');
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
  }
}
