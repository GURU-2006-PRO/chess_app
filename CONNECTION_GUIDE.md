# Chess Game Connection Guide

## ✅ Complete Setup Steps

### Phone A (Host Player - White)

1. **Enable Mobile Hotspot**
   - Go to Settings → Network & Internet → Hotspot & Tethering
   - Turn on "Mobile Hotspot"
   - Note the hotspot name and password
   - **Important**: The hotspot IP is usually `192.168.43.1` or `192.168.137.1`

2. **Launch the Chess App**
   - Open the app on Phone A
   - Tap **"Host Game (Start Server)"**
   - Wait for green banner showing IP (e.g., `192.168.43.1:4040`)
   - **Keep this screen open** - don't lock phone

3. **Connect to Your Own Server**
   - In Hostname field: Enter `127.0.0.1` (or the IP shown)
   - Port: `4040`
   - Tap **"Join Game (Connect)"**
   - You'll see "Waiting for opponent..." with spinner

### Phone B (Joiner Player - Black)

1. **Connect to Phone A's Hotspot**
   - Go to Wi-Fi settings
   - Find Phone A's hotspot name
   - Connect using the password
   - **Turn off mobile data** to ensure traffic goes through hotspot

2. **Launch the Chess App**
   - Open the app on Phone B
   - In Hostname field: Enter Phone A's IP (e.g., `192.168.43.1`)
   - Port: `4040`
   - Tap **"Join Game (Connect)"**

3. **Game Starts**
   - Both phones show "Both players connected!"
   - 3-2-1 countdown appears
   - Game starts - White (Phone A) moves first
   - Black (Phone B) sees board flipped

## 🔧 Troubleshooting

### "Connection timed out" Error

**Cause**: Phone B can't reach Phone A's server

**Solutions**:
1. ✅ Verify Phone A has started the server (green banner visible)
2. ✅ Verify Phone B is connected to Phone A's hotspot (not regular Wi-Fi)
3. ✅ Turn off mobile data on Phone B
4. ✅ Keep Phone A's app in foreground (don't lock screen)
5. ✅ Use the exact IP shown on Phone A (usually `192.168.43.1` for hotspot)
6. ✅ Try restarting both phones if issue persists

### Alternative: Same Wi-Fi Network

If hotspot doesn't work, both phones can connect to the same Wi-Fi router:

1. Connect both phones to the same Wi-Fi network
2. Phone A: Host game, note the IP (e.g., `192.168.1.23`)
3. Phone B: Enter that IP and connect
4. **Note**: Some routers block peer-to-peer connections (AP isolation)

### Check Server is Running

On Phone A after hosting, you should see in console:
```
Server started on 192.168.43.1:4040
Found IP on wlan0: 192.168.43.1
```

### Check Connection from Phone B

When Phone B connects, Phone A console should show:
```
Client connected: 192.168.43.xxx:xxxxx
Total clients: 2
Both players connected! Notifying clients...
```

## 🎮 Gameplay

- **White (Phone A)**: Moves first, pieces at bottom
- **Black (Phone B)**: Waits for white, pieces at bottom (board flipped)
- **Turn indicator**: Shows "Your Turn" or "Opponent's Turn"
- **Chat**: Send messages in real-time
- **Resign**: Tap flag icon to resign

## 📱 Network Requirements

- Both phones must be on the same network (hotspot or Wi-Fi)
- Port 4040 must be accessible
- Keep host app in foreground
- Stable connection required for real-time gameplay

## 🚨 Common Mistakes

❌ Phone B using mobile data instead of hotspot
❌ Wrong IP address entered on Phone B
❌ Phone A's screen locked (server stops)
❌ Both phones on different networks
❌ Using `127.0.0.1` on Phone B (that's Phone B's own loopback)

## ✅ Success Indicators

- Phone A: Green "Server Running" banner visible
- Phone B: Successfully connects without timeout
- Both phones: See "Waiting for opponent..." then countdown
- Both phones: Can see each other's moves in real-time
