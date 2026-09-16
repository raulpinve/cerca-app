import 'dart:convert';

import 'package:app/features/location/data/models/location_history_point.dart';
import 'package:app/features/location/data/models/member_location_response.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/auth/auth_token_provider.dart';

class LocationRepository {
  final _authTokenProvider = AuthTokenProvider();

  Future<void> updateMyLocation({
    required double latitude,
    required double longitude,
    required double accuracyM,
  }) async {
    final token = await _authTokenProvider.getIdToken();

    if (token == null) {
      throw Exception('No hay usuario autenticado');
    }

    final response = await http.put(
      Uri.parse('${AppConfig.apiHost}/locations/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        'accuracyM': accuracyM,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'No se pudo actualizar la ubicación (${response.statusCode})',
      );
    }
  }

  Future<List<MemberLocationResponse>> getCircleLocations(
    String circleId,
  ) async {
    final token = await _authTokenProvider.getIdToken();

    if (token == null) {
      throw Exception('No hay usuario autenticado');
    }

    final url = Uri.parse(
      '${AppConfig.apiHost}/locations/circles/$circleId',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] as List;

      debugPrint('Respuesta cruda: $data');

      return data.map((e) => MemberLocationResponse.fromJson(e)).toList();
    }

    throw Exception(
      'Error al obtener ubicaciones: ${response.statusCode}',
    );
  }

  Future<List<LocationHistoryPoint>> getUserHistory(
    String userId, {
    int limit = 20,
  }) async {
    final token = await _authTokenProvider.getIdToken();

    if (token == null) {
      throw Exception('No hay usuario autenticado');
    }

    final url = Uri.parse(
      '${AppConfig.apiHost}/locations/users/$userId/history?limit=$limit',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      final data = json['data'] as List;

      return data
          .map(
            (e) => LocationHistoryPoint.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    throw Exception(
      'Error al obtener historial: ${response.statusCode}',
    );
  }

  Future<String> getMyUserId() async {
    final token = await _authTokenProvider.getIdToken();

    if (token == null) {
      throw Exception('No hay usuario autenticado');
    }

    final url = Uri.parse(
      '${AppConfig.apiHost}/users/me',
    );

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      return json['data']['id'] as String;
    }

    throw Exception(
      'Error al obtener usuario actual: ${response.statusCode}',
    );
  }
}
