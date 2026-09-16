import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'package:app/core/config/app_config.dart';
import 'package:app/core/auth/auth_token_provider.dart';

class SocketService {
  final _authTokenProvider = AuthTokenProvider();

  io.Socket? _socket;

  Future<void> connect({
    required void Function(Map<String, dynamic> data) onLocationUpdate,
  }) async {
    final token = await _authTokenProvider.getIdToken();

    if (token == null) return;

    _socket = io.io(
      AppConfig.apiHost,
      io.OptionBuilder().setTransports(['websocket']).setAuth({
        'token': token,
      }).build(),
    );

    _socket!.onConnect(
      (_) => debugPrint('Socket conectado'),
    );

    _socket!.onDisconnect(
      (_) => debugPrint('Socket desconectado'),
    );

    _socket!.onConnectError(
      (err) => debugPrint('Error de conexión socket: $err'),
    );

    _socket!.on('location:update', (data) {
      onLocationUpdate(
        Map<String, dynamic>.from(data),
      );
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
