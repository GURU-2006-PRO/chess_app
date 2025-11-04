import 'dart:async';

import 'package:flutter/material.dart';

import 'chess_logic.dart';
import 'models.dart';
import 'tcp_service.dart';
import 'embedded_server.dart';

void main() {
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TCP Chess',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.grey.shade900,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark),
      ),
      home: const _ConnectionScreen(),
    );
  }
}

class _ConnectionScreen extends StatefulWidget {
  const _ConnectionScreen();

  @override
  State<_ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<_ConnectionScreen> {
  final hostController = TextEditingController(text: '127.0.0.1');
  final portController = TextEditingController(text: '4040');
  bool connecting = false;
  String? error;
  EmbeddedServer? embeddedServer;
  String? serverIp;

  @override
  void dispose() {
    hostController.dispose();
    portController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final host = hostController.text.trim();
    final portText = portController.text.trim();
    final port = int.tryParse(portText);
    if (host.isEmpty || port == null) {
      setState(() {
        error = 'Please enter a valid host and port';
      });
      return;
    }

    setState(() {
      connecting = true;
      error = null;
    });

    final chessLogic = ChessLogic();
    final tcpService = TcpService();

    final connected = ValueNotifier<bool>(false);
    final gameState = ValueNotifier<GameState>(GameState(
      board: chessLogic.board.toList(),
      currentPlayer: chessLogic.currentPlayer,
      moves: chessLogic.moves.toList(),
      messages: const [],
    ));

    final messageController = StreamController<String>.broadcast();
    void handleIncoming(String raw) {
      print('Received message: $raw');
      if (raw == 'PLAYER_JOINED') {
        print('PLAYER_JOINED detected! Starting countdown...');
        messageController.add('PLAYER_JOINED');
      } else if (raw.startsWith('MOVE:')) {
        final notation = raw.substring(5);
        final success = chessLogic.makeMove(notation);
        if (success) {
          gameState.value = GameState(
            board: chessLogic.board.toList(),
            currentPlayer: chessLogic.currentPlayer,
            moves: chessLogic.moves.toList(),
            messages: List<Message>.from(gameState.value.messages),
          );
          
          // Check for checkmate
          if (chessLogic.isGameOver) {
            final winner = chessLogic.currentPlayer == 'white' ? 'Black' : 'White';
            messageController.add('CHECKMATE! $winner wins!');
          }
        }
      } else if (raw.startsWith('MSG:')) {
        final content = raw.substring(4);
        final messages = List<Message>.from(gameState.value.messages)
          ..add(Message(sender: 'Opponent', content: content, timestamp: DateTime.now()));
        gameState.value = gameState.value.copyWith(messages: messages);
      } else if (raw == 'RESIGN') {
        chessLogic.resign(chessLogic.currentPlayer);
        messageController.add('Opponent resigned. You win.');
        gameState.value = GameState(
          board: chessLogic.board.toList(),
          currentPlayer: chessLogic.currentPlayer,
          moves: chessLogic.moves.toList(),
          messages: List<Message>.from(gameState.value.messages),
        );
      } else {
        messageController.add('Unknown message: $raw');
      }
    }

    tcpService
      ..onMessage = handleIncoming
      ..onConnected = () {
        connected.value = true;
      }
      ..onDisconnected = () {
        connected.value = false;
        messageController.add('Disconnected from server');
      }
      ..onError = (error) {
        messageController.add('Error: $error');
      };

    try {
      print('Attempting to connect to $host:$port');
      await tcpService.connect(host, port);
      print('Connected successfully!');
      
      if (!mounted) {
        await tcpService.disconnect();
        return;
      }
      if (context.mounted) {
        // Determine if this is the host (connecting to own server)
        final isHost = serverIp != null || host == '127.0.0.1' || host == 'localhost';
        print('Is host: $isHost');
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _GameScreen(
              chessLogic: chessLogic,
              tcpService: tcpService,
              connectionNotifier: connected,
              gameStateNotifier: gameState,
              transientMessages: messageController.stream,
              isHost: isHost,
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('Connection error: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        error = 'Connection failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          connecting = false;
        });
      }
    }
  }

  Future<void> _hostGame() async {
    setState(() {
      connecting = true;
      error = null;
    });

    try {
      embeddedServer = EmbeddedServer();
      final ip = await embeddedServer!.start(port: 4040);
      
      setState(() {
        serverIp = ip;
        hostController.text = '127.0.0.1';
        error = null;
        connecting = false;
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server started! Share IP: $ip:4040\nNow tap "Join Game" to connect as White player'),
            duration: const Duration(seconds: 8),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        error = 'Failed to start server: $e';
        connecting = false;
        embeddedServer = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCP Chess'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (serverIp != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Server Running', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Share this IP with opponent: $serverIp:4040'),
                  ],
                ),
              ),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(labelText: 'Hostname'),
              enabled: !connecting && serverIp == null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: portController,
              decoration: const InputDecoration(labelText: 'Port'),
              keyboardType: TextInputType.number,
              enabled: !connecting && serverIp == null,
            ),
            const SizedBox(height: 24),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error!, style: const TextStyle(color: Colors.redAccent)),
              ),
            if (serverIp == null)
              ElevatedButton.icon(
                onPressed: connecting ? null : _hostGame,
                icon: const Icon(Icons.dns),
                label: const Text('Host Game (Start Server)'),
              ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: connecting ? null : _connect,
              icon: const Icon(Icons.login),
              label: connecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Join Game (Connect)'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Instructions:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text('• Host: Tap "Host Game" to start server on this device'),
            const Text('• Join: Enter host IP and tap "Join Game"'),
            const Text('• Both players must be on same Wi-Fi network'),
          ],
        ),
      ),
    );
  }
}

class _GameScreen extends StatefulWidget {
  const _GameScreen({
    required this.chessLogic,
    required this.tcpService,
    required this.connectionNotifier,
    required this.gameStateNotifier,
    required this.transientMessages,
    required this.isHost,
  });

  final ChessLogic chessLogic;
  final TcpService tcpService;
  final ValueNotifier<bool> connectionNotifier;
  final ValueNotifier<GameState> gameStateNotifier;
  final Stream<String> transientMessages;
  final bool isHost;

  @override
  State<_GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<_GameScreen> {
  late StreamSubscription<String> transientSubscription;
  final TextEditingController chatController = TextEditingController();
  String? selectedSquare;
  String infoMessage = '';
  bool selfConnected = false;
  int countdown = 3;
  bool gameStarted = false;
  bool countdownStarted = false;
  int connectedPlayers = 0;

  @override
  void initState() {
    super.initState();
    transientSubscription = widget.transientMessages.listen((event) {
      if (!mounted) return;
      
      print('Game screen received event: $event');
      if (event == 'PLAYER_JOINED') {
        print('Starting countdown from game screen...');
        // Second player joined, start countdown
        _startCountdown();
      } else {
        setState(() {
          infoMessage = event;
        });
      }
    });
    widget.connectionNotifier.addListener(_handleConnectionChange);
    selfConnected = widget.connectionNotifier.value;
    
    // Show waiting message
    setState(() {
      infoMessage = 'Waiting for opponent to join...';
    });
  }

  void _startCountdown() async {
    if (countdownStarted) return;
    countdownStarted = true;
    
    setState(() {
      infoMessage = 'Both players connected! Starting game...';
    });
    
    await Future.delayed(const Duration(milliseconds: 1000));
    
    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() {
        countdown = i;
      });
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) {
      setState(() {
        gameStarted = true;
        infoMessage = 'Game started!';
      });
    }
  }

  @override
  void dispose() {
    transientSubscription.cancel();
    widget.connectionNotifier.removeListener(_handleConnectionChange);
    chatController.dispose();
    widget.tcpService.disconnect();
    super.dispose();
  }

  void _handleConnectionChange() {
    if (!mounted) return;
    setState(() {
      selfConnected = widget.connectionNotifier.value;
      if (!selfConnected) {
        infoMessage = 'Disconnected';
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = chatController.text.trim();
    if (text.isEmpty) {
      return;
    }
    chatController.clear();
    final messages = List<Message>.from(widget.gameStateNotifier.value.messages)
      ..add(Message(sender: 'You', content: text, timestamp: DateTime.now()));
    widget.gameStateNotifier.value = widget.gameStateNotifier.value.copyWith(messages: messages);
    try {
      await widget.tcpService.send('MSG:$text');
    } catch (e) {
      setState(() {
        infoMessage = 'Failed to send message: $e';
      });
    }
  }

  Future<void> _attemptMove(String square) async {
    if (!gameStarted) {
      setState(() {
        infoMessage = 'Wait for countdown...';
      });
      return;
    }

    if (!selfConnected) {
      setState(() {
        infoMessage = 'Not connected';
      });
      return;
    }

    final gameState = widget.gameStateNotifier.value;
    final isWhiteTurn = widget.chessLogic.currentPlayer == 'white';
    
    // Host plays white, joiner plays black
    final myColor = widget.isHost ? 'white' : 'black';
    final isMyTurn = widget.chessLogic.currentPlayer == myColor;

    if (!isMyTurn) {
      setState(() {
        infoMessage = 'Opponent\'s turn';
      });
      return;
    }

    if (selectedSquare == null) {
      final squareCoord = _squareFromBoardIndex(square);
      if (squareCoord == null) {
        return;
      }
      final piece = widget.chessLogic.board[squareCoord.$1][squareCoord.$2];
      if (piece == null || widget.chessLogic.currentPlayer != widget.chessLogic.pieceColor(piece)) {
        setState(() {
          infoMessage = 'Select your piece';
        });
        return;
      }
      setState(() {
        selectedSquare = square;
        infoMessage = 'Piece selected';
      });
      return;
    }

    final moveNotation = '$selectedSquare-$square';
    final success = widget.chessLogic.makeMove(moveNotation);
    if (!success) {
      setState(() {
        infoMessage = 'Illegal move';
      });
      return;
    }

    try {
      await widget.tcpService.send('MOVE:$moveNotation');
      widget.gameStateNotifier.value = GameState(
        board: widget.chessLogic.board.toList(),
        currentPlayer: widget.chessLogic.currentPlayer,
        moves: widget.chessLogic.moves.toList(),
        messages: gameState.messages,
      );
      
      // Check for checkmate after your move
      if (widget.chessLogic.isGameOver) {
        final winner = widget.chessLogic.currentPlayer == 'white' ? 'Black' : 'White';
        setState(() {
          selectedSquare = null;
          infoMessage = 'CHECKMATE! $winner wins!';
        });
        _showGameOverDialog(winner);
        return;
      }
    } catch (e) {
      setState(() {
        infoMessage = 'Failed to send move: $e';
      });
    }

    setState(() {
      selectedSquare = null;
      infoMessage = 'Move sent';
    });
  }

  void _showGameOverDialog(String winner) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            const SizedBox(width: 12),
            const Text('Game Over'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$winner Wins!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.amberAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isHost
                  ? (winner == 'White' ? 'You won!' : 'You lost!')
                  : (winner == 'Black' ? 'You won!' : 'You lost!'),
              style: TextStyle(
                fontSize: 18,
                color: (widget.isHost && winner == 'White') || (!widget.isHost && winner == 'Black')
                    ? Colors.greenAccent
                    : Colors.redAccent,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Return to connection screen
            },
            child: const Text('Exit Game'),
          ),
        ],
      ),
    );
  }

  Future<void> _resign() async {
    widget.chessLogic.resign('white');
    try {
      await widget.tcpService.send('RESIGN');
    } catch (e) {
      setState(() {
        infoMessage = 'Failed to send resign: $e';
      });
    }
    setState(() {
      infoMessage = 'You resigned';
    });
    _showGameOverDialog(widget.isHost ? 'Black' : 'White');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCP Chess'),
        actions: [
          IconButton(
            onPressed: _resign,
            icon: const Icon(Icons.flag),
            tooltip: 'Resign',
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            ValueListenableBuilder<GameState>(
              valueListenable: widget.gameStateNotifier,
              builder: (context, state, _) {
                final playerTurn = state.currentPlayer == 'white' ? 'White' : 'Black';
                final myColor = widget.isHost ? 'white' : 'black';
                final isYourTurn = state.currentPlayer == myColor;
                final myColorName = widget.isHost ? 'White' : 'Black';
                return Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueGrey.shade800,
                        Colors.blueGrey.shade700,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isYourTurn ? Icons.play_circle_filled : Icons.pause_circle_filled,
                                color: isYourTurn ? Colors.greenAccent : Colors.orangeAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isYourTurn ? 'Your Turn' : 'Opponent\'s Turn',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You are $myColorName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(
                            selfConnected ? Icons.wifi : Icons.wifi_off,
                            color: selfConnected ? Colors.greenAccent : Colors.redAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            selfConnected ? 'Connected' : 'Disconnected',
                            style: TextStyle(
                              fontSize: 14,
                              color: selfConnected ? Colors.greenAccent : Colors.redAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              flex: 5,
              child: ValueListenableBuilder<GameState>(
                valueListenable: widget.gameStateNotifier,
                builder: (context, state, _) {
                  return Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                          border: Border.all(color: Colors.brown.shade800, width: 8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: Stack(
                            children: [
                              GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 8,
                                ),
                                itemCount: 64,
                                itemBuilder: (context, index) {
                                  // Flip board for black player
                                  final displayIndex = widget.isHost ? index : (63 - index);
                                  final row = displayIndex ~/ 8;
                                  final col = displayIndex % 8;
                                  final squareName = _indexToSquare(row, col);
                                  final piece = state.board[row][col];
                                  final isDark = (row + col) % 2 == 1;
                              final isSelected = selectedSquare == squareName;
                              
                              return GestureDetector(
                                onTap: () => _attemptMove(squareName),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [
                                              Colors.amber.shade400,
                                              Colors.amber.shade600,
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : LinearGradient(
                                            colors: isDark
                                                ? [
                                                    const Color(0xFFB58863),
                                                    const Color(0xFFA07856),
                                                  ]
                                                : [
                                                    const Color(0xFFF0D9B5),
                                                    const Color(0xFFE8D1A8),
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: Colors.amber.withOpacity(0.6),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      // Coordinate labels
                                      if (col == 0)
                                        Positioned(
                                          left: 2,
                                          top: 2,
                                          child: Text(
                                            '${8 - row}',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? const Color(0xFFF0D9B5)
                                                  : const Color(0xFFB58863),
                                            ),
                                          ),
                                        ),
                                      if (row == 7)
                                        Positioned(
                                          right: 2,
                                          bottom: 2,
                                          child: Text(
                                            String.fromCharCode('a'.codeUnitAt(0) + col),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? const Color(0xFFF0D9B5)
                                                  : const Color(0xFFB58863),
                                            ),
                                          ),
                                        ),
                                      // Chess piece
                                      Center(
                                        child: piece != null
                                            ? Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.3),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  _symbolFor(piece),
                                                  style: TextStyle(
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.w500,
                                                    color: piece.startsWith('w')
                                                        ? Colors.white
                                                        : Colors.black,
                                                    shadows: [
                                                      Shadow(
                                                        color: piece.startsWith('w')
                                                            ? Colors.black.withOpacity(0.8)
                                                            : Colors.white.withOpacity(0.8),
                                                        offset: const Offset(1, 1),
                                                        blurRadius: 2,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink(),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                              // Countdown overlay
                              if (!gameStarted)
                                Container(
                                  color: Colors.black.withOpacity(0.8),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        if (!countdownStarted) ...[
                                          const CircularProgressIndicator(
                                            color: Colors.amberAccent,
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            'Waiting for opponent...',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ] else ...[
                                          Text(
                                            'Game Starting...',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            '$countdown',
                                            style: TextStyle(
                                              fontSize: 80,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amberAccent,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.amber,
                                                  blurRadius: 20,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade900,
                      Colors.grey.shade800,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade800,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble, size: 18, color: Colors.white70),
                          const SizedBox(width: 8),
                          const Text(
                            'Chat',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (infoMessage.isNotEmpty) ...[
                            const Spacer(),
                            Flexible(
                              child: Text(
                                infoMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.amberAccent,
                                  fontStyle: FontStyle.italic,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      child: ValueListenableBuilder<GameState>(
                        valueListenable: widget.gameStateNotifier,
                        builder: (context, state, _) {
                          return ListView.builder(
                            padding: const EdgeInsets.all(8),
                            itemCount: state.messages.length,
                            itemBuilder: (context, index) {
                              final message = state.messages[index];
                              final isYou = message.sender == 'You';
                              return Align(
                                alignment: isYou ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  constraints: const BoxConstraints(maxWidth: 250),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isYou
                                          ? [Colors.blue.shade700, Colors.blue.shade800]
                                          : [Colors.grey.shade700, Colors.grey.shade800],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        message.sender,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isYou
                                              ? Colors.lightBlueAccent
                                              : Colors.amberAccent,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        message.content,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: chatController,
                              style: const TextStyle(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: TextStyle(color: Colors.grey.shade600),
                                filled: true,
                                fillColor: Colors.grey.shade800,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue.shade600, Colors.blue.shade800],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.send, color: Colors.white),
                              onPressed: _sendMessage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _symbolFor(String piece) {
    return switch (piece) {
      'wK' => '♔',
      'wQ' => '♕',
      'wR' => '♖',
      'wB' => '♗',
      'wN' => '♘',
      'wP' => '♙',
      'bK' => '♚',
      'bQ' => '♛',
      'bR' => '♜',
      'bB' => '♝',
      'bN' => '♞',
      'bP' => '♟',
      _ => '',
    };
  }

  (int, int)? _squareFromBoardIndex(String square) {
    if (square.length != 2) {
      return null;
    }
    final file = square[0].codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.tryParse(square[1]);
    if (file < 0 || file > 7 || rank == null || rank < 1 || rank > 8) {
      return null;
    }
    final row = 8 - rank;
    return (row, file);
  }

  String _indexToSquare(int row, int col) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + col);
    final rank = (8 - row).toString();
    return '$file$rank';
  }
}
