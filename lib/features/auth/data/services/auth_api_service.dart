import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;

class AuthApiService {
  static const String baseUrl = 'http://10.0.2.2:3000';

  Future<void> registrarUsuario(String idToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error al registrar usuario: '
        '${response.statusCode} ${response.body}',
      );
    }

    debugPrint('Usuario registrado correctamente');
    debugPrint(jsonDecode(response.body));
  }
}
