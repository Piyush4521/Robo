import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/joint.dart';

class JointAngleCard extends StatelessWidget {
  final Joint joint;
  final VoidCallback? onTap;

  const JointAngleCard({
    super.key,
    required this.joint,
    this.onTap,
  });

  Color _getJointColor() {
    switch (joint.id) {
      case 0: return AppColors.jointBase;
      case 1: return AppColors.jointShoulder;
      case 2: return AppColors.jointElbow;
      case 3: return AppColors.jointLowerArm;
      case 4: return AppColors.jointWrist;
      case 5: return AppColors.jointGripper;
      default: return AppColors.primary;
    }
  }

  IconData _getJointIcon() {
    switch (joint.id) {
      case 0: return Icons.rotate_right_rounded;
      case 1: return Icons.timeline_rounded;
      case 2: return Icons.hub_rounded;
      case 3: return Icons.cable_rounded;
      case 4: return Icons.swap_horiz_rounded;
      case 5: return Icons.pan_tool_alt_rounded;
      default: return Icons.precision_manufacturing;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getJointColor();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Compact Joint Icon Badge
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getJointIcon(),
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 6),
            // Text Details with FittedBox protection against overflow
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      joint.name,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${joint.commandedAngle.toStringAsFixed(0)}°',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JointAngleGrid extends StatelessWidget {
  final List<Joint> joints;
  final Function(int jointId)? onJointSelected;

  const JointAngleGrid({
    super.key,
    required this.joints,
    this.onJointSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 360;
        final spacing = isSmallScreen ? 6.0 : 8.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: isSmallScreen ? 1.45 : 1.55,
          ),
          itemCount: joints.length,
          itemBuilder: (context, index) {
            return JointAngleCard(
              joint: joints[index],
              onTap: () => onJointSelected?.call(index),
            );
          },
        );
      },
    );
  }
}
