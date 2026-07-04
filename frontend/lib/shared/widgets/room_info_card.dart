import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import 'glass_card.dart';

class RoomInfoCard extends StatelessWidget {
  final String roomName;
  final String roomCode;

  const RoomInfoCard({
    super.key,
    required this.roomName,
    required this.roomCode,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  roomName,
                  style: AppTextStyles.heading.copyWith(fontSize: 22, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: const Text(
                  "ACTIVE LOBBY",
                  style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            "Room Code",
            style: AppTextStyles.body.copyWith(color: Colors.white38),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SelectableText(
                  roomCode,
                  style: AppTextStyles.heading.copyWith(
                    fontSize: 28,
                    color: AppColors.primary,
                    letterSpacing: 1,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: AppColors.primary.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: roomCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.card,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text("Room Code copied: $roomCode", style: const TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, color: Colors.white60),
                tooltip: "Copy Room Code",
              ),
            ],
          ),
        ],
      ),
    );
  }
}