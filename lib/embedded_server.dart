import 'dart:io';
import 'dart:convert';

class EmbeddedServer {
  final List<Socket> clients = [];
  ServerSocket? _serverSocket;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Future<String> start({int port = 4040}) async {
    if (_isRunning) {
      throw StateError('Server already running');
    }

    try {
      // Try binding to all interfaces
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _isRunning = true;

      // Get ALL local IP addresses
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      
      final ips = <String>[];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            ips.add(addr.address);
            print('Found IP on ${interface.name}: ${addr.address}');
          }
        }
      }

      final localIp = ips.isNotEmpty ? ips.first : '0.0.0.0';
      print('Server started on $localIp:$port');
      print('All available IPs: ${ips.join(", ")}');

      _serverSocket!.listen((client) {
        _handleClient(client);
      });

      // Return all IPs if multiple found
      return ips.isNotEmpty ? ips.join(' or ') : '0.0.0.0';
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
  }

  void _handleClient(Socket client) async {
    print('Client connected: ${client.remoteAddress.address}:${client.remotePort}');
    clients.add(client);
    print('Total clients: ${clients.length}');

    // Notify all clients when second player joins
    if (clients.length == 2) {
      print('Both players connected! Notifying clients...');
      // Small delay to ensure both clients are ready to receive
      await Future.delayed(const Duration(milliseconds: 500));
      for (final c in clients) {
        try {
          c.write('PLAYER_JOINED\n');
          await c.flush();
          print('Sent PLAYER_JOINED to client');
        } catch (e) {
          print('Error notifying client: $e');
        }
      }
    }

    client.listen(
      (data) {
        final message = utf8.decode(data).trim();
        if (message.isEmpty) return;

        print('Received: $message');

        // Relay to all other clients
        for (final otherClient in clients) {
          if (otherClient != client) {
            try {
              otherClient.write('$message\n');
              print('Relayed: $message');
            } catch (e) {
              print('Error relaying: $e');
            }
          }
        }
      },
      onDone: () {
        clients.remove(client);
        print('Client disconnected. Remaining: ${clients.length}');
      },
      onError: (error) {
        print('Client error: $error');
        clients.remove(client);
      },
      cancelOnError: true,
    );
  }

  Future<void> stop() async {
    for (final client in clients) {
      await client.close();
    }
    clients.clear();
    await _serverSocket?.close();
    _serverSocket = null;
    _isRunning = false;
    print('Server stopped');
  }
}
