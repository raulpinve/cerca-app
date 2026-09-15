import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/auth/auth_token_provider.dart';
import 'package:app/features/location/data/models/device.dart';

/// El usuario no tiene sesión válida (token nulo/expirado). Distinto de
/// "no vinculado": aquí ni siquiera podemos intentar registrar nada.
class AuthenticationException implements Exception {
  final String message;
  AuthenticationException(this.message);
  @override
  String toString() => message;
}

/// Hubo sesión, pero no se pudo registrar/verificar el dispositivo
/// (fallo de red, backend caído, respuesta inesperada, etc.)
class DeviceRegistrationException implements Exception {
  final String message;
  DeviceRegistrationException(this.message);
  @override
  String toString() => message;
}

class DeviceRepository {
  static const _deviceIdKey = 'device_id';
  final _authTokenProvider = AuthTokenProvider();

  Future<String?> getSavedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_deviceIdKey);
  }

  Future<void> _saveDeviceId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceIdKey, deviceId);
  }

  Future<void> clearSavedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
  }

  /// Ahora SIEMPRE valida contra el backend antes de reutilizar un id
  /// guardado localmente. Si el id ya no existe (fue eliminado desde
  /// otro lado), limpia el local y registra uno nuevo automáticamente.
  Future<String> getOrRegisterDeviceId() async {
    final saved = await getSavedDeviceId();
    debugPrint('DeviceId guardado localmente: $saved');

    if (saved != null) {
      final stillLinked = await _verifyDeviceLinked(saved);
      if (stillLinked) return saved;
      debugPrint('DeviceId "$saved" ya no está vinculado, limpiando...');
      await clearSavedDeviceId();
    }

    debugPrint('Registrando un dispositivo nuevo...');
    final device = await _registerDevice();
    await _saveDeviceId(device.id);
    return device.id;
  }

  /// GET /devices/{id} → 200 si sigue vinculado, 404 si no.
  /// Ante cualquier error de red/servidor que NO sea un 404 explícito,
  /// asumimos que sigue vinculado (fail-open) para no desvincular al
  /// usuario por un simple corte de conexión.
  Future<bool> _verifyDeviceLinked(String deviceId) async {
    final token = await _getToken();
    if (token == null) {
      throw AuthenticationException('No hay usuario autenticado');
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConfig.apiHost}/devices/$deviceId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      debugPrint(
        'Verificación device $deviceId → status ${response.statusCode}',
      );

      if (response.statusCode == 404) return false;
      if (response.statusCode == 200) return true;

      // Otro código (500, etc.): no sabemos con certeza, fail-open.
      debugPrint('Status inesperado verificando device, se asume vinculado');
      return true;
    } on SocketException catch (_) {
      debugPrint('Sin conexión al verificar device, se asume vinculado');
      return true;
    } catch (e) {
      debugPrint('Error inesperado verificando device: $e, se asume vinculado');
      return true;
    }
  }

  Future<Device> _registerDevice() async {
    final token = await _getToken();
    if (token == null) {
      throw AuthenticationException('No hay usuario autenticado');
    }

    final url = Uri.parse('${AppConfig.apiHost}/devices');
    late final http.Response response;
    try {
      response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'deviceName': await _getDeviceName(),
          'platform': Platform.isAndroid ? 'android' : 'ios',
        }),
      );
    } catch (e) {
      throw DeviceRegistrationException('No hay conexión con el servidor.');
    }

    debugPrint('POST /devices → ${response.statusCode}: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Device.fromJson(json['data']);
    }
    throw DeviceRegistrationException(
      'No se pudo registrar el dispositivo (${response.statusCode}).',
    );
  }

  Future<String?> _getToken() async {
    try {
      return await _authTokenProvider.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Future<String> _getDeviceName() async {
    return Platform.isAndroid ? 'Android device' : 'iPhone';
  }
}
