import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../shared/widgets/page_background.dart';
import '../../shared/widgets/primary_button.dart';
import '../room/create_room_screen.dart';
import '../room/join_room_screen.dart';
import 'widgets/home_header.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Glassmorphic Login/Lobby Card Container
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 450),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.02),
                        borderRadius: BorderRadius.circular(35),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header Logo & Branding
                          const HomeHeader(),
                          
                          const SizedBox(height: 35),
                          
                          // Create Room CTA
                          PrimaryButton(
                            title: "Create Room",
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CreateRoomScreen(),
                                ),
                              );
                            },
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                          
                          const SizedBox(height: AppSpacing.md),
                          
                          // Join Room CTA
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const JoinRoomScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                double.infinity,
                                58,
                              ),
                              side: const BorderSide(
                                color: Color(0xFF00D4FF),
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text(
                              "Join Room",
                              style: TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                        ],
                      ),
                    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack).fadeIn(),
                    
                    const SizedBox(height: 40),
                    
                    const Text(
                      "Version 1.0",
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}