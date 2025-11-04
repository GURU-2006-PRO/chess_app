import 'package:flutter/foundation.dart';

class Move {
  const Move({
    required this.fromSquare,
    required this.toSquare,
    required this.piece,
    this.capture = false,
  });

  final String fromSquare;
  final String toSquare;
  final String piece;
  final bool capture;
}

class Message {
  const Message({
    required this.sender,
    required this.content,
    required this.timestamp,
  });

  final String sender;
  final String content;
  final DateTime timestamp;
}

class GameState {
  const GameState({
    required this.board,
    required this.currentPlayer,
    required this.moves,
    required this.messages,
  });

  final List<List<String?>> board;
  final String currentPlayer;
  final List<Move> moves;
  final List<Message> messages;

  GameState copyWith({
    List<List<String?>>? board,
    String? currentPlayer,
    List<Move>? moves,
    List<Message>? messages,
  }) {
    return GameState(
      board: board ?? this.board,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      moves: moves ?? this.moves,
      messages: messages ?? this.messages,
    );
  }
}
