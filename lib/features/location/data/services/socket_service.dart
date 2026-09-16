import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:app/core/config/app_config.dart';
import 'package:app/core/auth/auth_token_provider.dart';

class SocketService {
  final _authTokenProvider = AuthTokenProvider();
  IO.Socket? _socket;

  Future<void> connect({
    required void Function(Map<String, dynamic> data) onLocationUpdate,
  }) async {
    final token = await _authTokenProvider.getIdToken();
    if (token == null) return;

    _socket = IO.io(
      AppConfig.apiHost,
      IO.OptionBuilder().setTransports(['websocket']).setAuth({
        'token': token,
      }).build(),
    );

    _socket!.onConnect((_) => print('Socket conectado'));
    _socket!.onDisconnect((_) => print('Socket desconectado'));
    _socket!.onConnectError((err) => print('Error de conexión socket: $err'));

    _socket!.on('location:update', (data) {
      onLocationUpdate(Map<String, dynamic>.from(data));
    });
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
