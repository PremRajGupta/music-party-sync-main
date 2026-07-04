import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/room_service.dart';
import '../../core/services/socket_service.dart';
import '../../models/room.dart';
import '../../shared/widgets/page_background.dart';
import '../waiting_room/waiting_room_screen.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final roomCodeController = TextEditingController();
  final nameController = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    roomCodeController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> joinRoom() async {
    if (roomCodeController.text.trim().isEmpty ||
        nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter Room Code and Your Name"),
        ),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final Room room = await RoomService.joinRoom(
        roomCodeController.text.trim(),
        nameController.text.trim(),
      );

      if (!mounted) return;

      SocketService.instance.userName = nameController.text.trim();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WaitingRoomScreen(room: room),
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
                            color: AppColors.success.withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.sensors_rounded,
                            color: AppColors.success,
                            size: 45,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "TUNE IN LOUNGE",
                          style: AppTextStyles.heading.copyWith(
                            fontSize: 24,
                            letterSpacing: 2,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Enter room details to sync and listen together",
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
                        // Room Code Input
                        TextField(
                          controller: roomCodeController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration(
                            labelText: "Room Code (e.g. SB-XXXXXX)",
                            icon: Icons.vpn_key_rounded,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Guest Name Input
                        TextField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: _buildInputDecoration(
                            labelText: "Your Name",
                            icon: Icons.person_rounded,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(height: 35),
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: loading ? null : joinRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.black,
                              disabledBackgroundColor: AppColors.success.withOpacity(0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 8,
                              shadowColor: AppColors.success.withOpacity(0.5),
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
                                    "Join Room & Sync",
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