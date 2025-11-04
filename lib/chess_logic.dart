import 'dart:collection';

import 'models.dart';

class ChessLogic {
  ChessLogic() {
    _resetBoard();
  }

  late List<List<String?>> _board;
  String _currentPlayer = 'white';
  final List<Move> _moveHistory = [];
  bool _gameOver = false;

  UnmodifiableListView<List<String?>> get board =>
      UnmodifiableListView(_board.map((row) => List<String?>.from(row)));

  String get currentPlayer => _currentPlayer;

  UnmodifiableListView<Move> get moves => UnmodifiableListView(_moveHistory);

  bool get isGameOver => _gameOver;

  String pieceColor(String piece) => _colorOf(piece);

  List<List<String?>> boardSnapshot() => _cloneBoard(_board);

  void reset() {
    _resetBoard();
    _currentPlayer = 'white';
    _moveHistory.clear();
    _gameOver = false;
  }

  bool makeMove(String notation) {
    if (_gameOver) {
      return false;
    }

    final parts = notation.split('-');
    if (parts.length != 2) {
      return false;
    }

    final from = _parseSquare(parts[0].trim());
    final to = _parseSquare(parts[1].trim());
    if (from == null || to == null) {
      return false;
    }

    final piece = _board[from.row][from.col];
    if (piece == null) {
      return false;
    }

    final movingColor = _colorOf(piece);
    if (movingColor != _currentPlayer) {
      return false;
    }

    if (!_isDestinationAvailable(piece, to)) {
      return false;
    }

    if (!_isValidPieceMove(_board, from, to, piece)) {
      return false;
    }

    final tempBoard = _cloneBoard(_board);
    final capturedPiece = tempBoard[to.row][to.col];
    tempBoard[to.row][to.col] = piece;
    tempBoard[from.row][from.col] = null;

    if (_isKingInCheck(tempBoard, _currentPlayer)) {
      return false;
    }

    _board = tempBoard;
    final capture = capturedPiece != null;
    _moveHistory.add(Move(
      fromSquare: parts[0].trim(),
      toSquare: parts[1].trim(),
      piece: piece,
      capture: capture,
    ));

    final opponent = _opponentOf(_currentPlayer);
    if (_isKingInCheck(_board, opponent) && !_hasAnyLegalMoves(_board, opponent)) {
      _gameOver = true;
    }

    _currentPlayer = opponent;
    return true;
  }

  bool isCheckmate(String color) {
    return _isKingInCheck(_board, color) && !_hasAnyLegalMoves(_board, color);
  }

  bool isInCheck(String color) {
    return _isKingInCheck(_board, color);
  }

  void resign(String color) {
    if (!_gameOver) {
      _gameOver = true;
      _currentPlayer = _opponentOf(color);
    }
  }

  void _resetBoard() {
    _board = List<List<String?>>.generate(8, (_) => List<String?>.filled(8, null));
    const backRank = ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R'];

    for (var i = 0; i < 8; i++) {
      _board[0][i] = 'b${backRank[i]}';
      _board[1][i] = 'bP';
      _board[6][i] = 'wP';
      _board[7][i] = 'w${backRank[i]}';
    }
  }

  bool _isDestinationAvailable(String piece, _Square to) {
    final target = _board[to.row][to.col];
    if (target == null) {
      return true;
    }
    return _colorOf(target) != _colorOf(piece);
  }

  bool _isValidPieceMove(
    List<List<String?>> boardState,
    _Square from,
    _Square to,
    String piece,
  ) {
    if (from == to) {
      return false;
    }

    final color = _colorOf(piece);
    final deltaRow = to.row - from.row;
    final deltaCol = to.col - from.col;
    final absRow = deltaRow.abs();
    final absCol = deltaCol.abs();

    final pieceType = piece.substring(1);
    switch (pieceType) {
      case 'P':
        final direction = color == 'white' ? -1 : 1;
        final startRow = color == 'white' ? 6 : 1;

        final targetPiece = boardState[to.row][to.col];
        if (deltaCol == 0) {
          if (deltaRow == direction && targetPiece == null) {
            return true;
          }
          if (from.row == startRow && deltaRow == 2 * direction) {
            final intermediateRow = from.row + direction;
            if (boardState[intermediateRow][from.col] == null && targetPiece == null) {
              return true;
            }
          }
          return false;
        }

        if (absCol == 1 && deltaRow == direction) {
          if (targetPiece != null && _colorOf(targetPiece) != color) {
            return true;
          }
        }
        return false;
      case 'R':
        if (deltaRow != 0 && deltaCol != 0) {
          return false;
        }
        return _isPathClear(boardState, from, to);
      case 'B':
        if (absRow != absCol) {
          return false;
        }
        return _isPathClear(boardState, from, to);
      case 'Q':
        if (deltaRow == 0 || deltaCol == 0 || absRow == absCol) {
          return _isPathClear(boardState, from, to);
        }
        return false;
      case 'N':
        return (absRow == 2 && absCol == 1) || (absRow == 1 && absCol == 2);
      case 'K':
        if (absRow <= 1 && absCol <= 1) {
          final futureBoard = _cloneBoard(boardState);
          futureBoard[to.row][to.col] = piece;
          futureBoard[from.row][from.col] = null;
          return !_isSquareAttacked(futureBoard, to, _opponentOf(color));
        }
        return false;
      default:
        return false;
    }
  }

  bool _isPathClear(List<List<String?>> boardState, _Square from, _Square to) {
    final stepRow = (to.row - from.row).sign;
    final stepCol = (to.col - from.col).sign;

    var currentRow = from.row + stepRow;
    var currentCol = from.col + stepCol;

    while (currentRow != to.row || currentCol != to.col) {
      if (boardState[currentRow][currentCol] != null) {
        return false;
      }
      currentRow += stepRow;
      currentCol += stepCol;
    }
    final target = boardState[to.row][to.col];
    if (target == null) {
      return true;
    }
    return _colorOf(target) != _colorOf(boardState[from.row][from.col]!);
  }

  bool _isKingInCheck(List<List<String?>> boardState, String color) {
    final kingPos = _findKing(boardState, color);
    if (kingPos == null) {
      return true;
    }
    return _isSquareAttacked(boardState, kingPos, _opponentOf(color));
  }

  _Square? _findKing(List<List<String?>> boardState, String color) {
    final target = color == 'white' ? 'wK' : 'bK';
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        if (boardState[row][col] == target) {
          return _Square(row, col);
        }
      }
    }
    return null;
  }

  bool _isSquareAttacked(
    List<List<String?>> boardState,
    _Square square,
    String attackerColor,
  ) {
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final piece = boardState[row][col];
        if (piece == null || _colorOf(piece) != attackerColor) {
          continue;
        }
        final from = _Square(row, col);
        if (!_isDestinationAvailableForBoard(boardState, piece, square)) {
          continue;
        }
        if (_isValidPieceMove(boardState, from, square, piece)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _hasAnyLegalMoves(List<List<String?>> boardState, String color) {
    for (var row = 0; row < 8; row++) {
      for (var col = 0; col < 8; col++) {
        final piece = boardState[row][col];
        if (piece == null || _colorOf(piece) != color) {
          continue;
        }
        final from = _Square(row, col);
        for (var targetRow = 0; targetRow < 8; targetRow++) {
          for (var targetCol = 0; targetCol < 8; targetCol++) {
            if (row == targetRow && col == targetCol) {
              continue;
            }
            final to = _Square(targetRow, targetCol);
            if (!_isDestinationAvailableForBoard(boardState, piece, to)) {
              continue;
            }
            if (!_isValidPieceMove(boardState, from, to, piece)) {
              continue;
            }
            final tempBoard = _cloneBoard(boardState);
            tempBoard[targetRow][targetCol] = piece;
            tempBoard[row][col] = null;
            if (!_isKingInCheck(tempBoard, color)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  bool _isDestinationAvailableForBoard(
    List<List<String?>> boardState,
    String piece,
    _Square to,
  ) {
    final target = boardState[to.row][to.col];
    if (target == null) {
      return true;
    }
    return _colorOf(target) != _colorOf(piece);
  }

  String _colorOf(String piece) => piece.startsWith('w') ? 'white' : 'black';

  String _opponentOf(String color) => color == 'white' ? 'black' : 'white';

  _Square? _parseSquare(String square) {
    if (square.length != 2) {
      return null;
    }
    final file = square[0].toLowerCase();
    final rank = square[1];
    if (file.compareTo('a') < 0 || file.compareTo('h') > 0) {
      return null;
    }
    final column = file.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rankValue = int.tryParse(rank);
    if (rankValue == null || rankValue < 1 || rankValue > 8) {
      return null;
    }
    final row = 8 - rankValue;
    return _Square(row, column);
  }

  List<List<String?>> _cloneBoard(List<List<String?>> boardState) {
    return List<List<String?>>.generate(
      8,
      (row) => List<String?>.from(boardState[row]),
    );
  }
}

class _Square {
  const _Square(this.row, this.col);

  final int row;
  final int col;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _Square && other.row == row && other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);
}
