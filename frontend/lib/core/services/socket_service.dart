import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static final SocketService instance = SocketService._internal();

  late IO.Socket socket;
  String? userName;

  SocketService._internal();

  void connect() {
    socket = IO.io(
      "https://music-party-socket.onrender.com",
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      debugPrint("✅ Socket Connected");
    });

    socket.onDisconnect((_) {
      debugPrint("❌ Socket Disconnected");
    });
  }

  void joinRoom(String roomId) {
    socket.emit("join-room", {
      "roomId": roomId,
      "userName": userName,
    });
  }

  void leaveRoom(String roomId) {
    socket.emit("leave-room", roomId);
  }

  void startParty(String roomId) {
    socket.emit("start-party", roomId);
  }

  // Playback Control Sync Senders
  void sendPlaybackState(String roomId, bool isPlaying) {
    socket.emit("media-toggle", {
      "roomId": roomId,
      "isPlaying": isPlaying,
    });
  }

  void sendSeek(String roomId, double progress, {int? positionMs, int? durationMs}) {
    socket.emit("media-seek", {
      "roomId": roomId,
      "progress": progress,
      "positionMs": positionMs,
      "durationMs": durationMs,
    });
  }

  void sendSongChange(String roomId, int songIndex) {
    socket.emit("media-change", {
      "roomId": roomId,
      "songIndex": songIndex,
    });
  }

  void sendLocalSongInfo(String roomId, String songName) {
    socket.emit("media-local-change", {
      "roomId": roomId,
      "songName": songName,
    });
  }

  void onRequestHostSync(Function(dynamic) callback) {
    socket.on("request-host-sync", callback);
  }

  // Playback Control Sync Receivers
  void onRoomUpdated(Function(dynamic) callback) {
    socket.on("room-updated", callback);
  }

  void onPartyStarted(Function(dynamic) callback) {
    socket.on("party-started", callback);
  }

  void onPlaybackStateChanged(Function(dynamic) callback) {
    socket.on("media-toggle-broadcast", callback);
  }

  void onSeekChanged(Function(dynamic) callback) {
    socket.on("media-seek-broadcast", callback);
  }

  void onSongChanged(Function(dynamic) callback) {
    socket.on("media-change-broadcast", callback);
  }

  void onLocalSongChanged(Function(dynamic) callback) {
    socket.on("media-local-change-broadcast", callback);
  }

  void onRoomCancelled(Function() callback) {
    socket.off("room-cancelled");
    socket.on("room-cancelled", (_) => callback());
  }

  void offRoomCancelled() {
    socket.off("room-cancelled");
  }

  void dispose() {
    socket.dispose();
  }
}