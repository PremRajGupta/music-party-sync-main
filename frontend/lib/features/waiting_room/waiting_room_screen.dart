import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/room_service.dart';
import '../../models/room.dart';
import '../../shared/widgets/page_background.dart';
import '../../shared/widgets/participant_tile.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/qr_card.dart';
import '../../shared/widgets/room_info_card.dart';
import '../player/player_screen.dart';

class WaitingRoomScreen extends StatefulWidget {
  final Room room;

  const WaitingRoomScreen({
    super.key,
    required this.room,
  });

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  late Room room;

  @override
  void initState() {
    super.initState();
    room = widget.room;

    SocketService.instance.connect();
    SocketService.instance.joinRoom(room.roomId);

    SocketService.instance.onRoomUpdated((data) {
      final updatedRoom = Room.fromJson(data);
      if (!mounted) return;
      setState(() {
        room = updatedRoom;
      });
    });

    SocketService.instance.onPartyStarted((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(room: room),
        ),
      );
    });

    SocketService.instance.onRoomCancelled(() {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("The host has closed this room."),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  @override
  void dispose() {
    final isHost = SocketService.instance.userName == room.hostName;
    if (isHost) {
      RoomService.deleteRoom(room.roomId);
    }
    SocketService.instance.leaveRoom(room.roomId);
    SocketService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHost = SocketService.instance.userName == room.hostName;

    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                ),
                const SizedBox(height: 10),
                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Waiting Room",
                      style: AppTextStyles.heading.copyWith(fontSize: 28),
                    ).animate().fadeIn().slideX(begin: -0.1),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            "LIVE LOBBY",
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().scale(),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final desktop = constraints.maxWidth > 900;

                      if (desktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                children: [
                                  RoomInfoCard(
                                    roomName: room.roomName,
                                    roomCode: room.roomId,
                                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                                  const SizedBox(height: AppSpacing.lg),
                                  QRCard(roomId: room.roomId)
                                      .animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Participants (${room.members.length})",
                                    style: AppTextStyles.title.copyWith(color: Colors.white70),
                                  ).animate().fadeIn().slideX(begin: 0.1),
                                  const SizedBox(height: AppSpacing.md),
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: room.members.length,
                                      itemBuilder: (context, idx) {
                                        final member = room.members[idx];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                          child: ParticipantTile(
                                            name: member.name,
                                            isHost: member.host,
                                          ).animate().fadeIn(delay: (50 * idx).ms).slideX(begin: 0.05),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  _buildActionButton(isHost),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      // Mobile Layout
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RoomInfoCard(
                              roomName: room.roomName,
                              roomCode: room.roomId,
                            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                            const SizedBox(height: AppSpacing.lg),
                            QRCard(roomId: room.roomId)
                                .animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              "Participants (${room.members.length})",
                              style: AppTextStyles.title.copyWith(color: Colors.white70),
                            ).animate().fadeIn(),
                            const SizedBox(height: AppSpacing.md),
                            // List of members
                            Column(
                              children: List.generate(room.members.length, (idx) {
                                final member = room.members[idx];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                  child: ParticipantTile(
                                    name: member.name,
                                    isHost: member.host,
                                  ).animate().fadeIn(delay: (50 * idx).ms).slideX(begin: 0.05),
                                );
                              }),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            _buildActionButton(isHost),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(bool isHost) {
    if (isHost) {
      return PrimaryButton(
        title: "Start Party",
        onTap: () {
          SocketService.instance.startParty(room.roomId);
        },
      ).animate().fadeIn().scale();
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white30,
              ),
            ),
            const SizedBox(width: 15),
            Text(
              "Waiting for host to start the party...",
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ).animate().fadeIn();
    }
  }
}