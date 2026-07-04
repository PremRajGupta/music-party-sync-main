import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import 'glass_card.dart';

class QRCard extends StatelessWidget {
  final String roomId;

  const QRCard({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        children: [
          Text(
            "Room QR Code",
            style: AppTextStyles.title.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: QrImageView(
              data: roomId,
              version: QrVersions.auto,
              size: 160.0,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary.withOpacity(0.7), size: 18),
              const SizedBox(width: 8),
              Text(
                "Scan to join lobby",
                style: AppTextStyles.body.copyWith(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}