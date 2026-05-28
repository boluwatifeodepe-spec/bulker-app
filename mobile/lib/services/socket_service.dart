import 'package:bulker/config/constants.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? _socket;

  void connect({
    required void Function(Map<String, dynamic>) onProgress,
    required void Function(Map<String, dynamic>) onComplete,
    required void Function(Map<String, dynamic>) onPairingStatus,
  }) {
    try {
      _socket ??= io.io(
        AppConstants.backendUrl,
        io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build(),
      );

      _socket!
        ..on('campaign:progress', (data) {
          if (data is Map) onProgress(Map<String, dynamic>.from(data));
        })
        ..on('campaign:complete', (data) {
          if (data is Map) onComplete(Map<String, dynamic>.from(data));
        })
        ..on('whatsapp:status', (data) {
          if (data is Map) onPairingStatus(Map<String, dynamic>.from(data));
        })
        ..connect();
    } catch (_) {
      _socket = null;
    }
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}
