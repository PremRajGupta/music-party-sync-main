import 'member.dart';

class Room {
  final String roomId;
  final String roomName;
  final String hostName;
  final List<Member> members;
  final DateTime createdAt;
  final int currentSongIndex;
  final bool isPlaying;
  final double progress;
  final String? localSongName;

  Room({
    required this.roomId,
    required this.roomName,
    required this.hostName,
    required this.members,
    required this.createdAt,
    required this.currentSongIndex,
    required this.isPlaying,
    required this.progress,
    this.localSongName,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json["roomId"] ?? "",
      roomName: json["roomName"] ?? "",
      hostName: json["hostName"] ?? "",
      members: (json["members"] as List<dynamic>? ?? [])
          .map((e) => Member.fromJson(e))
          .toList(),
      createdAt: DateTime.tryParse(json["createdAt"] ?? "") ?? DateTime.now(),
      currentSongIndex: json["currentSongIndex"] ?? -1,
      isPlaying: json["isPlaying"] ?? false,
      progress: (json["progress"] as num?)?.toDouble() ?? 0.0,
      localSongName: json["localSongName"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "roomId": roomId,
      "roomName": roomName,
      "hostName": hostName,
      "members": members.map((e) => e.toJson()).toList(),
      "createdAt": createdAt.toIso8601String(),
      "currentSongIndex": currentSongIndex,
      "isPlaying": isPlaying,
      "progress": progress,
      "localSongName": localSongName,
    };
  }
}