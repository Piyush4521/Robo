import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/robot_state.dart';

class RobotConnectionBadge extends StatelessWidget {
  final ConnectionStatus status;
  final String? deviceName;
  final VoidCallback? onTap;

  const RobotConnectionBadge({
    super.key,
    required this.status,
    this.deviceName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = status == ConnectionStatus.connected;
    final isConnecting = status == ConnectionStatus.connecting ||
        status == ConnectionStatus.handshaking;

    final badgeColor = isConnected
        ? AppColors.statusGreen
        : (isConnecting ? AppColors.statusYellow : AppColors.textMuted);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular Bluetooth Icon with pulsating color
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.bluetooth,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isConnected
                      ? 'Connected'
                      : (isConnecting ? 'Connecting...' : 'Disconnected'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  deviceName ?? 'HC-05',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
