import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/room_service.dart';
import '../../core/services/socket_service.dart';
import '../../models/room.dart';
import '../../shared/widgets/page_background.dart';
import '../waiting_room/waiting_room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final roomController = TextEditingController();
  final hostController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    roomController.dispose();
    hostController.dispose();
    super.dispose();
  }

  Future<void> createRoom() async {
    if (roomController.text.trim().isEmpty ||
        hostController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Room Name and Host Name"),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final Room room = await RoomService.createRoom(
        roomController.text.trim(),
        hostController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Room Created: ${room.roomId}"),
        ),
      );

      SocketService.instance.userName = hostController.text.trim();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(
            room: room,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: SingleChildScrollView(
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
                  const SizedBox(height: 20),
                  // Title Header
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.settings_voice_rounded,
                            color: AppColors.primary,
                            size: 45,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "CREATE STUDIO",
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 24,
                            letterSpacing: 2,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Start your synchronized music stream",
                          style: TextStyle(color: Colors.white38, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Card Form Container
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Room Name Input
                        TextField(
                          controller: roomController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration(
                            labelText: "Room Name",
                            icon: Icons.music_video_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Host Name Input
                        TextField(
                          controller: hostController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration(
                            labelText: "Host / DJ Name",
                            icon: Icons.person_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 35),
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: loading ? null : createRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 8,
                              shadowColor: AppColors.primary.withOpacity(0.5),
                            ),
                            child: loading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Text(
                                    "Launch Studio Room",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData icon,
    required Color color,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 14),
      floatingLabelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
      prefixIcon: Icon(icon, color: color),
      filled: true,
      fillColor: Colors.white.withOpacity(0.01),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.06), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: color, width: 2),
      ),
    );
  }
}