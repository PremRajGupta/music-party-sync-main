import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import 'glass_card.dart';

class ParticipantTile extends StatelessWidget {
  final String name;
  final bool isHost;
  final bool isConnected;

  const ParticipantTile({
    super.key,
    required this.name,
    this.isHost = false,
    this.isConnected = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor = isHost ? AppColors.primary : AppColors.secondary;

    return GlassCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: themeColor.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withOpacity(0.02),
              child: Icon(
                isHost ? Icons.laptop_chromebook_rounded : Icons.phone_android_rounded,
                color: themeColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.title.copyWith(fontSize: 16, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isHost ? "HOST / DJ" : "GUEST / LISTENER",
                        style: TextStyle(
                          color: themeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Row(
              children: [
                Text(
                  isConnected ? "Connected" : "Disconnected",
                  style: TextStyle(
                    color: isConnected ? AppColors.success : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isConnected ? AppColors.success : Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isConnected ? AppColors.success : Colors.redAccent).withOpacity(0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}