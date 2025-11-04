# TCP Chess - Multiplayer Chess Game

A real-time multiplayer chess game built with Flutter that uses TCP socket communication for peer-to-peer gameplay. Play chess with a friend on two devices connected via Wi-Fi or mobile hotspot.

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## 📱 Features

- **Real-time Multiplayer**: Play chess with another player over TCP connection
- **Embedded Server**: One device hosts the game server, no external server needed
- **Beautiful UI**: Modern chess board with gradients, shadows, and animations
- **Turn-based Gameplay**: Proper turn management with visual indicators
- **Board Flip**: Black player sees the board from their perspective
- **Countdown Timer**: 3-2-1 countdown when both players connect
- **Live Chat**: Send messages to your opponent during the game
- **Checkmate Detection**: Automatic winner announcement with dialog
- **Resign Option**: Players can resign at any time
- **Connection Status**: Real-time connection indicator
- **No External Packages**: Pure Flutter implementation using only dart:io

## 🎮 How to Play

### Setup (Two Devices Required)

#### Phone A (Host - White Player)
1. Enable **Mobile Hotspot** in phone settings
2. Launch the chess app
3. Tap **"Host Game (Start Server)"**
4. Note the IP address shown (e.g., `192.168.43.1:4040`)
5. Tap **"Join Game (Connect)"** to join as White player
6. Wait for opponent with "Waiting for opponent..." screen

#### Phone B (Joiner - Black Player)
1. Connect to Phone A's hotspot in Wi-Fi settings
2. Turn off mobile data
3. Launch the chess app
4. Enter Phone A's IP address (e.g., `192.168.43.1`)
5. Port: `4040`
6. Tap **"Join Game (Connect)"** to join as Black player

#### Game Start
- Both players see "Both players connected!"
- 3-2-1 countdown appears on both screens
- Game starts - White moves first
- Black player sees board flipped (black pieces at bottom)

### Gameplay
- **Your Turn**: Green play icon, can move pieces
- **Opponent's Turn**: Orange pause icon, wait for opponent
- **Move Pieces**: Tap piece to select, tap destination to move
- **Chat**: Type messages in chat area and press send
- **Resign**: Tap flag icon in app bar to resign
- **Checkmate**: Dialog appears announcing winner

## 🏗️ Project Structure

```
chess/
├── lib/
│   ├── main.dart              # Main app, UI, connection screen, game screen
│   ├── chess_logic.dart       # Chess rules, move validation, checkmate detection
│   ├── tcp_service.dart       # TCP socket client for sending/receiving messages
│   ├── embedded_server.dart   # TCP server that relays messages between players
│   └── models.dart            # Data models (Move, Message, GameState)
├── server/
│   └── chess_server.dart      # Standalone Dart server (optional, not used in app)
├── pubspec.yaml               # Flutter dependencies (SDK only, no packages)
├── README.md                  # This file
├── CHESS_README.md            # Original implementation notes
└── CONNECTION_GUIDE.md        # Detailed connection troubleshooting guide
```

## 📦 Dependencies

**Zero external packages!** This project uses only Flutter SDK and Dart core libraries:

- `dart:io` - TCP socket communication
- `dart:async` - Streams and async operations
- `dart:convert` - UTF-8 encoding/decoding
- `flutter/material.dart` - UI components

## 🔧 Technical Implementation

### Architecture

```
┌─────────────┐         TCP Socket         ┌─────────────┐
│   Phone A   │◄──────────────────────────►│   Phone B   │
│   (White)   │      192.168.43.1:4040     │   (Black)   │
│             │                             │             │
│  ┌────────┐ │                             │  ┌────────┐ │
│  │ Client │ │                             │  │ Client │ │
│  └───┬────┘ │                             │  └───┬────┘ │
│      │      │                             │      │      │
│  ┌───▼────┐ │                             │      │      │
│  │ Server │ │  Relays messages between    │      │      │
│  │(Host)  │─┼─────────────────────────────┼──────┘      │
│  └────────┘ │         both clients        │             │
└─────────────┘                             └─────────────┘
```

### Message Protocol

Messages are sent as UTF-8 encoded strings with newline delimiters:

- `MOVE:e2-e4` - Chess move in algebraic notation
- `MSG:hello` - Chat message
- `RESIGN` - Player resignation
- `PLAYER_JOINED` - Server notification when second player connects

### Chess Logic

**Board Representation**: 8x8 2D array with piece notation
- White pieces: `wP`, `wR`, `wN`, `wB`, `wQ`, `wK`
- Black pieces: `bP`, `bR`, `bN`, `bB`, `bQ`, `bK`

**Move Validation**: Each piece type has specific movement rules
- Pawns: Forward 1 (or 2 from start), diagonal capture
- Rooks: Horizontal/vertical any distance
- Knights: L-shape (2+1 squares)
- Bishops: Diagonal any distance
- Queens: Horizontal/vertical/diagonal any distance
- Kings: One square in any direction

**Checkmate Detection**: 
- Checks if current player's king is under attack
- Verifies no legal moves can escape check
- Announces winner when checkmate occurs

**Not Implemented**: Castling, en passant, pawn promotion (for simplicity)

### UI Components

**Connection Screen**
- Host Game button (starts embedded server)
- IP/Port input fields
- Join Game button (connects to server)
- Instructions and error messages

**Game Screen**
- Status bar (turn indicator, connection status, player color)
- Chess board (8x8 grid with coordinates)
  - Professional wood colors (#F0D9B5 light, #B58863 dark)
  - Gradient squares for depth
  - Animated selection with amber glow
  - Piece shadows for 3D effect
  - Flipped for black player
- Chat area (message bubbles, input field)
- Countdown overlay (waiting/3-2-1)
- Game over dialog (winner announcement)

### Network Communication

**TCP Server (Embedded)**
- Binds to `0.0.0.0:4040` (all network interfaces)
- Accepts multiple client connections
- Relays messages between connected clients
- Detects when 2 players join and triggers countdown
- Handles disconnections gracefully

**TCP Client**
- Connects to server via IP:port
- Sends moves and chat messages
- Listens for incoming messages line-by-line
- Callbacks for connection events
- Auto-reconnect not implemented (manual reconnect required)

## 🚀 Installation & Running

### Prerequisites
- Flutter SDK 3.0 or higher
- Dart 3.0 or higher
- Android device or emulator (iOS not tested)
- Two devices on same network

### Build & Install

```bash
# Clone the repository
git clone <repository-url>
cd chess

# Get dependencies (none to install, but runs Flutter checks)
flutter pub get

# Build release APK
flutter build apk --release

# Install on connected device
flutter install

# Or run in debug mode
flutter run
```

### APK Location
After building, find the APK at:
```
build/app/outputs/flutter-apk/app-release.apk
```

Transfer this APK to the second device and install.

## 🐛 Troubleshooting

### Connection Timeout
**Problem**: Phone B shows "Connection timed out"

**Solutions**:
1. ✅ Verify Phone A has started server (green banner visible)
2. ✅ Verify Phone B is connected to Phone A's hotspot
3. ✅ Turn off mobile data on Phone B
4. ✅ Use exact IP shown on Phone A (usually `192.168.43.1`)
5. ✅ Keep Phone A app in foreground (don't lock screen)
6. ✅ Try restarting both phones

### Waiting Forever
**Problem**: Phone B shows "Waiting for opponent..." forever

**Solutions**:
1. ✅ Ensure Phone A also tapped "Join Game" after hosting
2. ✅ Check server console shows "Total clients: 2"
3. ✅ Restart both apps and reconnect
4. ✅ Rebuild app with latest code

### Board Not Flipped
**Problem**: Black player sees white pieces at bottom

**Solution**: This is a bug if it happens. Black player should always see black pieces at bottom. Restart the app.

### Moves Not Syncing
**Problem**: Moves don't appear on opponent's board

**Solutions**:
1. ✅ Check connection status shows "Connected"
2. ✅ Verify it's your turn (green play icon)
3. ✅ Check console for "Relayed: MOVE:..." messages
4. ✅ Reconnect both players

### Checkmate Not Detected
**Problem**: Game continues after checkmate

**Solution**: This is a limitation of basic checkmate detection. Some complex positions may not be detected. Use resign button.

## 📝 Code Examples

### Starting the Server
```dart
final server = EmbeddedServer();
final ip = await server.start(port: 4040);
print('Server running on $ip:4040');
```

### Connecting as Client
```dart
final tcpService = TcpService();
await tcpService.connect('192.168.43.1', 4040);
tcpService.onMessage = (message) {
  print('Received: $message');
};
```

### Making a Move
```dart
final chessLogic = ChessLogic();
final success = chessLogic.makeMove('e2-e4');
if (success) {
  await tcpService.send('MOVE:e2-e4');
}
```

### Sending Chat
```dart
await tcpService.send('MSG:Good game!');
```

## 🎨 Customization

### Change Board Colors
Edit `lib/main.dart` around line 650:
```dart
colors: isDark
    ? [Color(0xFFB58863), Color(0xFFA07856)]  // Dark squares
    : [Color(0xFFF0D9B5), Color(0xFFE8D1A8)]  // Light squares
```

### Change Port
Edit `lib/embedded_server.dart` line 11:
```dart
Future<String> start({int port = 5000}) async {  // Change 4040 to 5000
```

### Countdown Duration
Edit `lib/main.dart` around line 350:
```dart
for (int i = 5; i > 0; i--) {  // Change 3 to 5 for 5-second countdown
```

## 🔒 Security Considerations

⚠️ **This is a local network game for educational purposes**

- No authentication or encryption
- Messages sent in plain text
- No protection against cheating
- Server accepts any client connection
- Not suitable for internet deployment
- Use only on trusted local networks

## 🤝 Contributing

Contributions welcome! Areas for improvement:

- [ ] Add castling, en passant, pawn promotion
- [ ] Implement move history/undo
- [ ] Add game timer/clock
- [ ] Save/load games
- [ ] Add AI opponent (single player)
- [ ] Improve checkmate detection
- [ ] Add stalemate detection
- [ ] Implement draw offers
- [ ] Add sound effects
- [ ] Add move animations
- [ ] Support for iOS
- [ ] Add spectator mode
- [ ] Implement ELO rating system

## 📄 License

MIT License - feel free to use this project for learning or personal use.

## 👨‍💻 Author

Created as a demonstration of Flutter TCP networking and real-time multiplayer game development.

## 🙏 Acknowledgments

- Chess piece Unicode symbols (♔♕♖♗♘♙)
- Flutter team for excellent framework
- Dart team for powerful language features

## 📚 Additional Resources

- [CONNECTION_GUIDE.md](CONNECTION_GUIDE.md) - Detailed connection troubleshooting
- [CHESS_README.md](CHESS_README.md) - Original implementation notes
- [Flutter Networking](https://docs.flutter.dev/development/data-and-backend/networking)
- [Dart Sockets](https://api.dart.dev/stable/dart-io/Socket-class.html)

---

**Enjoy playing chess with your friends! ♟️**
