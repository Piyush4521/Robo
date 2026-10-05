import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/robot_controller.dart';
import '../../models/robot_state.dart';
import '../../core/safety/target_validator.dart';
import '../../widgets/robot_view.dart';
import '../../widgets/joystick.dart';
import '../../widgets/emergency_stop.dart';

class ControlScreen extends StatefulWidget {
  final RobotController robotController;
  final VoidCallback? onSwitchToAnglesMode;

  const ControlScreen({
    super.key,
    required this.robotController,
    this.onSwitchToAnglesMode,
  });

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  int _controlMode = 0; // 0: Manual (Joysticks), 1: Angles (Target Sliders)
  int _activeTab = 0;   // 0: Base+Shoulder, 1: Elbow+Wrist, 2: Fine Control
  double _gripperSliderValue = 28.0;
  bool _isInteractingWithJoystick = false;

  @override
  void initState() {
    super.initState();
    _gripperSliderValue = widget.robotController.state.joints[5].commandedAngle;
  }

  void _handleLeftStick(double x, double y) {
    if (x.abs() < 0.15 && y.abs() < 0.15) {
      widget.robotController.stopJog(0);
      widget.robotController.stopJog(1);
      return;
    }

    if (x.abs() > y.abs()) {
      if (x > 0.15) {
        widget.robotController.startJogPositive(0);
      } else if (x < -0.15) {
        widget.robotController.startJogNegative(0);
      }
    } else {
      if (y > 0.15) {
        widget.robotController.startJogPositive(1);
      } else if (y < -0.15) {
        widget.robotController.startJogNegative(1);
      }
    }
  }

  void _handleRightStick(double x, double y) {
    if (x.abs() < 0.15 && y.abs() < 0.15) {
      widget.robotController.stopJog(2);
      widget.robotController.stopJog(4);
      return;
    }

    if (x.abs() > y.abs()) {
      if (x > 0.15) {
        widget.robotController.startJogPositive(4);
      } else if (x < -0.15) {
        widget.robotController.startJogNegative(4);
      }
    } else {
      if (y > 0.15) {
        widget.robotController.startJogPositive(2);
      } else if (y < -0.15) {
        widget.robotController.startJogNegative(2);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.robotController,
      builder: (context, _) {
        final state = widget.robotController.state;
        final gripperAngle = state.joints[5].commandedAngle;
        final isConnected = state.connectionState == ConnectionStatus.connected;
        final report = TargetValidator.validatePose(state.joints, state.targetAngles);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: _isInteractingWithJoystick
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title & Mode Switcher Pill: [Manual] vs [Angles]
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _controlMode == 0 ? 'Manual Control' : 'Angle Control',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _controlMode == 0
                                ? 'Game-style control for smooth operation'
                                : 'Precision six-axis target coordination',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      // Mode Switcher Pill
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () => setState(() => _controlMode = 0),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _controlMode == 0 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Manual',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _controlMode == 0 ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => setState(() => _controlMode = 1),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _controlMode == 1 ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Angles',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _controlMode == 1 ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Connection Alert Banner if Disconnected
                  if (!isConnected)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.statusYellow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.statusYellow.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.bluetooth_disabled, color: AppColors.statusYellow, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Robot not connected. Go to Settings tab to connect HC-05.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ESTOP Active Alert Banner with Reset Action
                  if (state.emergencyStopped)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.emergencyRed.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.emergencyRed, size: 24),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EMERGENCY STOP LATCHED',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.emergencyRed),
                                ),
                                Text(
                                  'All motor PWM signals are disabled.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => widget.robotController.resetEmergencyStop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.statusGreen,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            child: const Text('Reset', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),

                  // 3D Robot Arm Preview
                  Robot3DView(
                    angles: _controlMode == 1 ? state.targetAngles : state.currentCommandedAngles,
                    height: 175,
                    showControls: true,
                  ),
                  const SizedBox(height: 12),

                  // ========================
                  // MODE 0: MANUAL (JOYSTICKS)
                  // ========================
                  if (_controlMode == 0) ...[
                    // Sub-tabs: [Base + Shoulder] [Elbow + Wrist] [Fine Control]
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubTab(title: 'Base + Shoulder', icon: Icons.unfold_more, index: 0),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildSubTab(title: 'Elbow + Wrist', icon: Icons.cable_rounded, index: 1),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildSubTab(title: 'Fine Control', icon: Icons.tune, index: 2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_activeTab == 2)
                      _buildFineControlMode(state)
                    else
                      Row(
                        children: [
                          // Left Joystick (Base & Shoulder)
                          Expanded(
                            child: DualAxisJoystick(
                              title: 'Base & Shoulder',
                              upLabel: 'Shoulder +',
                              downLabel: 'Shoulder -',
                              leftLabel: 'Base -',
                              rightLabel: 'Base +',
                              onDragStateChanged: (dragging) {
                                setState(() => _isInteractingWithJoystick = dragging);
                              },
                              onDirectionChanged: _handleLeftStick,
                              onReleased: () {
                                widget.robotController.stopJog(0);
                                widget.robotController.stopJog(1);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Right Joystick (Elbow & Wrist)
                          Expanded(
                            child: DualAxisJoystick(
                              title: 'Elbow & Wrist',
                              upLabel: 'Elbow +',
                              downLabel: 'Elbow -',
                              leftLabel: 'Wrist -',
                              rightLabel: 'Wrist +',
                              onDragStateChanged: (dragging) {
                                setState(() => _isInteractingWithJoystick = dragging);
                              },
                              onDirectionChanged: _handleRightStick,
                              onReleased: () {
                                widget.robotController.stopJog(2);
                                widget.robotController.stopJog(4);
                              },
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),

                    // Gripper Control Section
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGripperButton(
                            icon: '()',
                            label: 'Open\nGripper',
                            onTap: () {
                              setState(() => _gripperSliderValue = 85.0);
                              widget.robotController.setGripperAngle(85.0);
                            },
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'Gripper: ${gripperAngle.toStringAsFixed(0)}°',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Slider(
                                  value: _gripperSliderValue.clamp(10.0, 90.0),
                                  min: 10.0,
                                  max: 90.0,
                                  onChanged: (val) {
                                    setState(() => _gripperSliderValue = val);
                                  },
                                  onChangeEnd: (val) {
                                    widget.robotController.setGripperAngle(val);
                                  },
                                ),
                              ],
                            ),
                          ),
                          _buildGripperButton(
                            icon: '()',
                            label: 'Close\nGripper',
                            onTap: () {
                              setState(() => _gripperSliderValue = 15.0);
                              widget.robotController.setGripperAngle(15.0);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Movement Speed Slider
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                              Row(
                                children: const [
                                  Icon(Icons.speed, size: 18, color: AppColors.textPrimary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Movement Speed',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                state.speedProfile == 1
                                    ? '30% (Slow)'
                                    : (state.speedProfile == 3 ? '100% (Fast)' : '60% (Normal)'),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: state.speedProfile.toDouble(),
                            min: 1.0,
                            max: 3.0,
                            divisions: 2,
                            onChanged: (val) {
                              widget.robotController.setSpeed(val.round());
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text('Slow', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                Text('Normal', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                Text('Fast', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // ========================
                  // MODE 1: ANGLES CONTROL
                  // ========================
                  else ...[
                    // Validation Warning if out of bounds
                    if (!report.allValid)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.emergencyRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: AppColors.emergencyRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                report.summaryError,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.emergencyRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 6 Target Sliders
                    ...List.generate(state.joints.length, (i) {
                      final joint = state.joints[i];
                      final target = state.targetAngles[i];
                      final diff = target - joint.commandedAngle;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border, width: 1.2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      joint.name,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('(${joint.servoType})', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Cmd: ${joint.commandedAngle.toStringAsFixed(0)}°',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: diff == 0 ? AppColors.surfaceSubtle : AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Target: ${target.toStringAsFixed(0)}° (${diff >= 0 ? '+' : ''}${diff.toStringAsFixed(0)}°)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: diff == 0 ? AppColors.textSecondary : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text('${joint.safeMin.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
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
                                Text('${joint.safeMax.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),

                    // Move to Target Pose Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (report.allValid && widget.robotController.isReady)
                            ? () => widget.robotController.moveToTargetPose()
                            : null,
                        icon: state.motionState == MotionStatus.movingToTarget
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.play_arrow_rounded, size: 20),
                        label: Text(
                          state.motionState == MotionStatus.movingToTarget
                              ? 'COORDINATED MOTION IN PROGRESS...'
                              : 'MOVE TO TARGET POSE',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // STOP ALL Emergency Button or Reset Button
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
                      subtitle: 'Emergency stop - All motors halt',
                      onPressed: () => widget.robotController.emergencyStop(),
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

  Widget _buildSubTab({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _activeTab == index;

    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGripperButton({
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          children: [
            Text(
              icon,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFineControlMode(RobotState state) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              const Text(
                'Select Single Joint for Precision Jog:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${state.joints[state.selectedJoint].name} (${state.joints[state.selectedJoint].commandedAngle.toStringAsFixed(0)}°)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(state.joints.length, (i) {
              final isSel = state.selectedJoint == i;
              return ChoiceChip(
                label: Text(state.joints[i].name),
                selected: isSel,
                onSelected: (val) {
                  if (val) widget.robotController.selectJoint(i);
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSel ? Colors.white : AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Listener(
                  onPointerDown: (_) => widget.robotController.startJogNegative(state.selectedJoint),
                  onPointerUp: (_) => widget.robotController.stopJog(state.selectedJoint),
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.remove_circle_outline, size: 16),
                    label: const Text('JOG - (Hold)', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceSubtle,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Listener(
                  onPointerDown: (_) => widget.robotController.startJogPositive(state.selectedJoint),
                  onPointerUp: (_) => widget.robotController.stopJog(state.selectedJoint),
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add_circle_outline, size: 16),
                    label: const Text('JOG + (Hold)', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
