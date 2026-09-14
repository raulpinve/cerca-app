import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/auth/auth_token_provider.dart';
import 'package:app/features/location/data/models/device.dart';

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

  Future<String> getOrRegisterDeviceId() async {
    final saved = await getSavedDeviceId();
    if (saved != null) return saved;

    final device = await _registerDevice();
    await _saveDeviceId(device.id);
    return device.id;
  }

  Future<Device> _registerDevice() async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) {
      throw Exception('No hay usuario autenticado');
    }

    final url = Uri.parse('${AppConfig.apiHost}/devices');

    final response = await http.post(
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

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return Device.fromJson(json['data']);
    } else {
      throw Exception(
        'No se pudo registrar el dispositivo: ${response.statusCode}',
      );
    }
  }

  Future<String> _getDeviceName() async {
    return Platform.isAndroid ? 'Android device' : 'iPhone';
  }

  Future<void> clearSavedDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_deviceIdKey);
  }
}
