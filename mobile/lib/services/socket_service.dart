import 'package:bulker/config/constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? _socket;

  void connect({
    required void Function(Map<String, dynamic>) onProgress,
    required void Function(Map<String, dynamic>) onComplete,
    required void Function(Map<String, dynamic>) onPairingStatus,
  }) {
    _socket ??= io.io(
      AppConstants.backendUrl,
      io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
    );

    _socket!
      ..on('campaign:progress', (data) {
        onProgress(Map<String, dynamic>.from(data as Map));
      })
      ..on('campaign:complete', (data) {
        onComplete(Map<String, dynamic>.from(data as Map));
      })
      ..on('whatsapp:status', (data) {
        onPairingStatus(Map<String, dynamic>.from(data as Map));
      })
      ..connect();
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
