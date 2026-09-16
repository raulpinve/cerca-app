import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:app/features/location/data/repositories/location_repository.dart';
import 'package:app/features/location/data/services/location_tracking_service.dart';

class AppLocationController {
  AppLocationController._internal();

  static final AppLocationController instance =
      AppLocationController._internal();

  final _locationService = LocationTrackingService();
  final _locationRepository = LocationRepository();

  bool _isRunning = false;

  final _positionController = StreamController<Position>.broadcast();

  Stream<Position> get positionStream => _positionController.stream;

  bool get isRunning => _isRunning;

  Future<bool>? _startFuture;

  Future<bool> start() async {
    if (_isRunning) return true;

    if (_startFuture != null) {
      return _startFuture!;
    }

    final completer = Completer<bool>();
    _startFuture = completer.future;

    try {
      final result = await _startInternal();

      completer.complete(result);

      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _startFuture = null;
    }
  }

  Future<bool> _startInternal() async {
    final started = await _locationService.start(
      onUpdate: _onPositionUpdate,
    );

    _isRunning = started;

    debugPrint('¿Tracking iniciado?: $started');

    return started;
  }

  void stop() {
    _locationService.stop();
    _isRunning = false;
  }

  void _onPositionUpdate(Position position) async {
    _positionController.add(position);

    try {
      await _locationRepository.updateMyLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
      );

      debugPrint(
        'Ubicación enviada: '
        '${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error al enviar ubicación: $e');
    }
  }

  void dispose() {
    stop();
    _positionController.close();
  }
}
