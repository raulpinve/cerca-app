import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:app/core/config/app_config.dart';
import 'package:app/core/auth/auth_token_provider.dart';
import 'package:app/features/mapa/data/models/circle_response.dart';

class CircleRepository {
  final _authTokenProvider = AuthTokenProvider();

  Future<List<CircleResponse>> getMyCircles() async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) throw Exception('No hay usuario autenticado');

    final url = Uri.parse('${AppConfig.apiHost}/circles');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] as List;
      debugPrint('Círculos crudos: $data');
      return data.map((e) => CircleResponse.fromJson(e)).toList();
    } else {
      throw Exception('Error al obtener círculos: ${response.statusCode}');
    }
  }

  Future<void> createCircle(String name) async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) throw Exception('No hay usuario autenticado');

    final url = Uri.parse('${AppConfig.apiHost}/circles');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al crear círculo: ${response.statusCode}');
    }
  }

  Future<void> leaveCircle(String circleId) async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) throw Exception('No hay usuario autenticado');

    final url = Uri.parse('${AppConfig.apiHost}/circles/$circleId/members/me');

    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body));
    }
  }

  Future<void> deleteCircle(String circleId) async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) throw Exception('No hay usuario autenticado');

    final url = Uri.parse('${AppConfig.apiHost}/circles/$circleId');

    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(_extractErrorMessage(response.body));
    }
  }

  String _extractErrorMessage(String body) {
    try {
      final json = jsonDecode(body);
      return json['message'] as String? ?? 'Ocurrió un error';
    } catch (_) {
      return 'Ocurrió un error';
    }
  }
}
