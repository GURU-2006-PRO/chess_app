import 'dart:io';
import 'dart:async';
import 'dart:convert';

void main() async {
  final server = ChessServer();
  await server.start();
}

class ChessServer {
  final List<Socket> clients = [];
  ServerSocket? serverSocket;

  Future<void> start({String host = '0.0.0.0', int port = 4040}) async {
    try {
      serverSocket = await ServerSocket.bind(host, port);
      print('Chess server listening on $host:$port');
      print('Waiting for players to connect...');

      await for (final client in serverSocket!) {
        handleClient(client);
      }
    } catch (e) {
      print('Server error: $e');
    }
  }

  void handleClient(Socket client) {
    final address = client.remoteAddress.address;
    final port = client.remotePort;
    print('Client connected: $address:$port');

    clients.add(client);
    print('Total clients: ${clients.length}');

    client.listen(
      (data) {
        final message = utf8.decode(data).trim();
        if (message.isEmpty) return;

        print('Received from $address:$port: $message');

        // Relay to all other clients
        for (final otherClient in clients) {
          if (otherClient != client) {
            try {
              otherClient.write('$message\n');
              print('Relayed to other client: $message');
            } catch (e) {
              print('Error relaying to client: $e');
            }
          }
        }
      },
      onDone: () {
        clients.remove(client);
        print('Client disconnected: $address:$port');
        print('Remaining clients: ${clients.length}');
      },
      onError: (error) {
        print('Error from client $address:$port: $error');
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
    await serverSocket?.close();
    print('Server stopped');
  }
}
