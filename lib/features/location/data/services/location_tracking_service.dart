import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationTrackingService {
  StreamSubscription<Position>? _positionStream;
  Timer? _heartbeatTimer;
  late final LocationSettings _locationSettings;

  LocationTrackingService() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      _locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: const Duration(seconds: 8),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: "Compartiendo ubicación",
          notificationText: "Tu familia puede verte en el mapa",
          enableWakeLock: true,
        ),
      );
    } else {
      _locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    }
  }

  Future<bool> requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    if (permission == LocationPermission.whileInUse) {
      permission =
          await Geolocator.requestPermission(); // pide "Allow all the time"
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> start({required void Function(Position) onUpdate}) async {
    final granted = await requestPermissions();
    if (!granted) return false;

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: _locationSettings,
        ).listen((position) {
          onUpdate(position);
        });

    _heartbeatTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      onUpdate(position);
    });

    return true;
  }

  void stop() {
    _positionStream?.cancel();
    _heartbeatTimer?.cancel();
    _positionStream = null;
    _heartbeatTimer = null;
  }

  bool get isTracking => _positionStream != null;
}
