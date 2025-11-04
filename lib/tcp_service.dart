import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef MessageHandler = void Function(String data);
typedef ConnectionStateHandler = void Function();
typedef ErrorHandler = void Function(Object error);

class TcpService {
  TcpService({
    MessageHandler? onMessage,
    ConnectionStateHandler? onConnected,
    ConnectionStateHandler? onDisconnected,
    ErrorHandler? onError,
  })  : onMessage = onMessage,
        onConnected = onConnected,
        onDisconnected = onDisconnected,
        onError = onError;

  MessageHandler? onMessage;
  ConnectionStateHandler? onConnected;
  ConnectionStateHandler? onDisconnected;
  ErrorHandler? onError;

  Socket? _socket;
  StreamSubscription<String>? _subscription;

  bool get isConnected => _socket != null;

  Future<void> connect(String host, int port) async {
    await disconnect();
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      _socket = socket;
      onConnected?.call();
      _subscription = socket
          .map((event) => utf8.decode(event))
          .transform(const LineSplitter())
          .listen(
        (data) {
          final message = data.trim();
          if (message.isEmpty) {
            return;
          }
          onMessage?.call(message);
        },
        onDone: _handleDisconnection,
        onError: (Object error) {
          onError?.call(error);
          _handleDisconnection();
        },
        cancelOnError: true,
      );
    } on SocketException catch (e) {
      onError?.call(e);
      rethrow;
    } catch (e) {
      onError?.call(e);
      rethrow;
    }
  }

  Future<void> send(String message) async {
    final socket = _socket;
    if (socket == null) {
      throw StateError('Socket is not connected');
    }
    try {
      socket.write('$message\n');
      await socket.flush();
    } catch (e) {
      onError?.call(e);
      await disconnect();
      rethrow;
    }
  }

  Future<void> disconnect() async {
    if (_subscription != null) {
      await _subscription?.cancel();
      _subscription = null;
    }
    if (_socket != null) {
      try {
        await _socket?.close();
      } catch (_) {
        // ignore close errors
      }
      _socket = null;
      onDisconnected?.call();
    }
  }

  void _handleDisconnection() {
    _socket = null;
    _subscription = null;
    onDisconnected?.call();
  }
}
