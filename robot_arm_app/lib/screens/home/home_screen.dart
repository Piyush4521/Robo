import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/robot_controller.dart';
import '../../models/robot_state.dart';
import '../../widgets/robot_view.dart';
import '../../widgets/robot_status.dart';
import '../../widgets/angle_row.dart';
import '../../widgets/emergency_stop.dart';

class HomeScreen extends StatelessWidget {
  final RobotController robotController;
  final Function(int targetTabIndex) onNavigateToTab;
  final VoidCallback onOpenSettings;

  const HomeScreen({
    super.key,
    required this.robotController,
    required this.onNavigateToTab,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: robotController,
      builder: (context, _) {
        final state = robotController.state;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top App Bar Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Title & Subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'ROBOT ARM',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            '6-DOF Controller',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),

                      // Right Controls: Settings Gear + Bluetooth Badge
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, size: 22),
                            color: AppColors.primary,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                            ),
                            onPressed: onOpenSettings,
                          ),
                          const SizedBox(width: 8),
                          RobotConnectionBadge(
                            status: state.connectionState,
                            deviceName: state.connectedDeviceName,
                            onTap: onOpenSettings,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 3D Robot Arm View
                  Robot3DView(
                    angles: state.currentCommandedAngles,
                    height: 225,
                    showControls: false,
                  ),
                  const SizedBox(height: 18),

                  // Status Banner
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.emergencyStopped
                                ? 'EMERGENCY STOP'
                                : (state.robotReady ? 'Ready' : (state.connectionState == ConnectionStatus.connecting ? 'Connecting...' : 'Disconnected')),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: state.emergencyStopped
                                  ? AppColors.emergencyRed
                                  : (state.robotReady ? AppColors.textPrimary : AppColors.textSecondary),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            state.emergencyStopped
                                ? 'Safety latch active. All PWM pulses shut off.'
                                : (state.robotReady
                                    ? 'Arm synchronized. PCA9685 PWM 50Hz active.'
                                    : 'Bluetooth disconnected. Pair HC-05 in Settings to control.'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Current Joint Angles Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Joint Angles',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.statusGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.statusGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Live',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.statusGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2x3 Grid of Joint Angles
                  JointAngleGrid(
                    joints: state.joints,
                    onJointSelected: (jointId) {
                      robotController.selectJoint(jointId);
                      onNavigateToTab(1); // Switch to manual control
                    },
                  ),
                  const SizedBox(height: 18),

                  // Quick Action Cards
                  Row(
                    children: [
                      // Home Position Card
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.home_rounded,
                          title: 'Home Position',
                          subtitle: 'Move to safe home pose',
                          onTap: () => robotController.moveToHome(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Saved Poses Card
                      Expanded(
                        child: _buildQuickActionCard(
                          icon: Icons.assignment_rounded,
                          title: 'Saved Poses',
                          subtitle: 'Quick access to poses',
                          onTap: () => onNavigateToTab(2), // Switch to Poses
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Emergency Stop Button
                  if (state.emergencyStopped)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => robotController.resetEmergencyStop(),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('RESET EMERGENCY STOP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    )
                  else
                    EmergencyStopButton(
                      onPressed: () => robotController.emergencyStop(),
                    ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
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
