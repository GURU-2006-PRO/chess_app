# TCP Chess Game

Minimal multiplayer chess game built with Flutter and TCP messaging.

## File Structure

```
lib/
├── main.dart          # UI & game screens (connection + game)
├── tcp_service.dart   # Socket handling with dart:io
├── chess_logic.dart   # Chess rules & move validation
└── models.dart        # Data classes (Move, Message, GameState)
```

## Features

- **Connection Screen**: Enter hostname and port to connect to server
- **Game Screen**: 
  - 8x8 chessboard with Unicode chess pieces (♔♕♖♗♘♙)
  - Click-to-select, click-to-move interface
  - Real-time chat messaging
  - Turn indicator
  - Resign button
- **Chess Logic**:
  - Full piece movement validation (pawn, rook, knight, bishop, queen, king)
  - Check and checkmate detection
  - Move validation prevents illegal moves
  - No castling, en passant, or pawn promotion (as per requirements)

## Message Protocol

```
MOVE:e2-e4    # Send/receive chess moves
MSG:hello     # Send/receive chat messages
RESIGN        # Player resignation
```

## Running the Application

### 1. Start the Python Server

```bash
python server.py
# Or specify custom port:
python server.py 5000
```

Default: `0.0.0.0:4040`

### 2. Run Flutter App (Two Instances)

```bash
# Terminal 1 - First player
flutter run

# Terminal 2 - Second player (different device/emulator)
flutter run -d <device_id>
```

### 3. Connect Both Players

- Enter hostname: `127.0.0.1` (or server IP)
- Enter port: `4040`
- Click "Connect"

### 4. Play Chess

- White moves first
- Click piece to select, click destination to move
- Chat messages appear below the board
- Game alternates turns automatically

## Gameplay Flow

1. Both players connect to TCP server
2. White player makes first move
3. Move is sent to server via TCP
4. Server relays move to opponent
5. Opponent's board updates automatically
6. Turn switches to black
7. Continue until checkmate or resign

## Technical Details

- **No external packages** - Uses only `dart:io` for networking
- **StatefulWidget** with `setState` for state management
- **ValueNotifier** for reactive UI updates
- **TCP relay server** forwards all messages between clients
- **Error handling** for disconnections and invalid moves

## Server Details

The Python server (`server.py`):
- Accepts multiple client connections
- Relays messages between connected players
- Handles disconnections gracefully
- Thread-safe client management
- Simple broadcast relay (no game logic on server)

## Notes

- Server must be running before clients connect
- Exactly 2 players needed for a game
- White always plays from bottom of board
- Connection lost = game interrupted
- No game state persistence
