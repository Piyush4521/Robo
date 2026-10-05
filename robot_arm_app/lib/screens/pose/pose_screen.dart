import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/robot_controller.dart';
import '../../models/robot_state.dart';
import '../../core/safety/target_validator.dart';
import '../../widgets/robot_view.dart';
import '../../widgets/emergency_stop.dart';

class PoseScreen extends StatefulWidget {
  final RobotController robotController;

  const PoseScreen({super.key, required this.robotController});

  @override
  State<PoseScreen> createState() => _PoseScreenState();
}

class _PoseScreenState extends State<PoseScreen> {
  bool _isPreviewMode = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.robotController,
      builder: (context, _) {
        final state = widget.robotController.state;
        final report = TargetValidator.validatePose(state.joints, state.targetAngles);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Pose Control',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Precision six-axis target coordination',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Target Preview Toggle Button
                      FilterChip(
                        label: const Text('Target Preview'),
                        selected: _isPreviewMode,
                        onSelected: (val) => setState(() => _isPreviewMode = val),
                        selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _isPreviewMode ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3D Visualization (Current vs Target Preview)
                  Robot3DView(
                    angles: _isPreviewMode ? state.targetAngles : state.currentCommandedAngles,
                    height: 185,
                    showControls: false,
                  ),
                  const SizedBox(height: 12),

                  // Validation Banner
                  if (!report.allValid)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              report.summaryError,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.emergencyRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Joint Target Sliders (6 Joints)
                  ...List.generate(state.joints.length, (i) {
                    final joint = state.joints[i];
                    final target = state.targetAngles[i];
                    final diff = target - joint.commandedAngle;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Joint Name & Servo
                              Row(
                                children: [
                                  Text(
                                    joint.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${joint.servoType})',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              // Current vs Target & Delta
                              Row(
                                children: [
                                  Text(
                                    'Cmd: ${joint.commandedAngle.toStringAsFixed(0)}°',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: diff == 0
                                          ? AppColors.surfaceSubtle
                                          : AppColors.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Target: ${target.toStringAsFixed(0)}° (${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}°)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: diff == 0 ? AppColors.textSecondary : AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                '${joint.safeMin.toStringAsFixed(0)}°',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                              Expanded(
                                child: Slider(
                                  value: target.clamp(joint.safeMin, joint.safeMax),
                                  min: joint.safeMin,
                                  max: joint.safeMax,
                                  onChanged: (val) {
                                    widget.robotController.updateTargetAngle(i, val);
                                  },
                                ),
                              ),
                              Text(
                                '${joint.safeMax.toStringAsFixed(0)}°',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),

                  // Coordinated Move Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (report.allValid && widget.robotController.isReady)
                          ? () => widget.robotController.moveToTargetPose()
                          : null,
                      icon: state.motionState == MotionStatus.movingToTarget
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(
                        state.motionState == MotionStatus.movingToTarget
                            ? 'COORDINATED MOTION IN PROGRESS...'
                            : 'MOVE TO TARGET POSE',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Stop All Emergency Button or Reset Button
                  if (state.emergencyStopped)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.robotController.resetEmergencyStop(),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('RESET EMERGENCY STOP'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusGreen,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    )
                  else
                    EmergencyStopButton(
                      label: 'STOP ALL',
                      subtitle: 'Immediate motion cancellation',
                      onPressed: () => widget.robotController.stopAll(),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
