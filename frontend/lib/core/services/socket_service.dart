import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../config/app_config.dart';

class SocketService {
  static final SocketService instance = SocketService._internal();

  late IO.Socket socket;
  String? userName;
  
  final StreamController<bool> _connectionStateController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  SocketService._internal();

  void connect() {
    socket = IO.io(
      AppConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)
          .setReconnectionDelay(2000)
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      debugPrint("✅ Socket Connected");
      _connectionStateController.add(true);
    });

    socket.onDisconnect((_) {
      debugPrint("❌ Socket Disconnected");
      _connectionStateController.add(false);
    });

    socket.onConnectError((e) {
      debugPrint("⚠️ Socket Connect Error: $e");
    });
  }

  void joinRoom(String roomId) {
    offPlaybackListeners();
    socket.emit("join-room", {
      "roomId": roomId,
      "userName": userName,
    });
  }

  void leaveRoom(String roomId) {
    socket.emit("leave-room", roomId);
    offPlaybackListeners();
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
    socket.off("request-host-sync");
    socket.on("request-host-sync", callback);
  }

  // Playback Control Sync Receivers
  void onRoomUpdated(Function(dynamic) callback) {
    socket.off("room-updated");
    socket.on("room-updated", callback);
  }

  void onPartyStarted(Function(dynamic) callback) {
    socket.off("party-started");
    socket.on("party-started", callback);
  }

  void onPlaybackStateChanged(Function(dynamic) callback) {
    socket.off("media-toggle-broadcast");
    socket.on("media-toggle-broadcast", callback);
  }

  void onSeekChanged(Function(dynamic) callback) {
    socket.off("media-seek-broadcast");
    socket.on("media-seek-broadcast", callback);
  }

  void onSongChanged(Function(dynamic) callback) {
    socket.off("media-change-broadcast");
    socket.on("media-change-broadcast", callback);
  }

  void onLocalSongChanged(Function(dynamic) callback) {
    socket.off("media-local-change-broadcast");
    socket.on("media-local-change-broadcast", callback);
  }

  void onRoomCancelled(Function() callback) {
    socket.off("room-cancelled");
    socket.on("room-cancelled", (_) => callback());
  }

  void offRoomCancelled() {
    socket.off("room-cancelled");
  }

  void offPlaybackListeners() {
    socket.off("room-updated");
    socket.off("party-started");
    socket.off("media-toggle-broadcast");
    socket.off("media-seek-broadcast");
    socket.off("media-change-broadcast");
    socket.off("media-local-change-broadcast");
    socket.off("request-host-sync");
  }

  void disconnect() {
    socket.disconnect();
  }

  void dispose() {
    _connectionStateController.close();
    socket.dispose();
  }
}