import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:app/core/config/app_config.dart';
import 'package:app/core/auth/auth_token_provider.dart';
import 'package:app/features/invitations/data/models/circle_invitation.dart';

class InvitationRepository {
  final _authTokenProvider = AuthTokenProvider();

  Future<List<CircleInvitation>> getMyPendingInvitations() async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) throw Exception('No hay usuario autenticado');

    final url = Uri.parse('${AppConfig.apiHost}/circle-invitations');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final data = json['data'] as List;
      return data.map((e) => CircleInvitation.fromJson(e)).toList();
    } else {
      throw Exception('Error al obtener invitaciones: ${response.statusCode}');
    }
  }

  Future<void> acceptInvitation(String invitationId) async {
    await _respondInvitation(invitationId, 'accept');
  }

  Future<void> rejectInvitation(String invitationId) async {
    await _respondInvitation(invitationId, 'reject');
  }

  Future<void> _respondInvitation(String invitationId, String action) async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) throw Exception('No hay usuario autenticado');

    final url = Uri.parse(
      '${AppConfig.apiHost}/circle-invitations/$invitationId/$action',
    );

    final response = await http.put(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error al responder invitación: ${response.statusCode}');
    }
  }

  Future<void> createInvitation({
    required String circleId,
    required String email,
  }) async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) throw Exception('No hay usuario autenticado');

    final url = Uri.parse('${AppConfig.apiHost}/circle-invitations');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'circleId': circleId, 'email': email}),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Error al crear invitación');
    }
  }
}
