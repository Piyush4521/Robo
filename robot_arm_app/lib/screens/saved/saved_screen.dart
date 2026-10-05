import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/robot_controller.dart';
import '../../services/preset_service.dart';
import '../../models/robot_pose.dart';
import '../../widgets/emergency_stop.dart';

class SavedScreen extends StatefulWidget {
  final RobotController robotController;
  final PresetService presetService;

  const SavedScreen({
    super.key,
    required this.robotController,
    required this.presetService,
  });

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _activeTab = 0; // 0: Poses, 1: Sequences

  void _showSavePoseDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Save Current Robot Pose'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Record the current 6 commanded angles into your local pose library.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Pose Name (e.g. Workbench Clear)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  widget.presetService.saveCurrentPose(
                    nameController.text.trim(),
                    descController.text.trim(),
                    widget.robotController.state.currentCommandedAngles,
                  );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Save Pose'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.robotController, widget.presetService]),
      builder: (context, _) {
        final poses = widget.presetService.savedPoses;
        final sequences = widget.presetService.sequences;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title & Save Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Saved Library',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.8,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Calibrated stances & sequence routines',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _showSavePoseDialog,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Save Current'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Mode Tabs: [Poses (5)] [Sequences (1)]
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeTab = 0),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeTab == 0 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Poses (${poses.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _activeTab == 0 ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _activeTab = 1),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _activeTab == 1 ? AppColors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  'Sequences (${sequences.length})',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _activeTab == 1 ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_activeTab == 0)
                    ...poses.map((pose) => _buildPoseCard(pose))
                  else
                    ...sequences.map((seq) => _buildSequenceCard(seq)),

                  const SizedBox(height: 20),
                  EmergencyStopButton(
                    onPressed: () {
                      widget.presetService.stopSequence();
                      widget.robotController.emergencyStop();
                    },
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

  Widget _buildPoseCard(RobotPose pose) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hub_outlined, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pose.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        pose.description,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () async {
                  for (int i = 0; i < pose.angles.length; i++) {
                    widget.robotController.updateTargetAngle(i, pose.angles[i]);
                  }
                  await widget.robotController.moveToTargetPose();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Move'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Angles breakdown chips
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildAngleChip('Base', pose.angles[0]),
              _buildAngleChip('Sh', pose.angles[1]),
              _buildAngleChip('Elb', pose.angles[2]),
              _buildAngleChip('Arm', pose.angles[3]),
              _buildAngleChip('Wr', pose.angles[4]),
              _buildAngleChip('Grip', pose.angles[5]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAngleChip(String label, double angle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        '$label: ${angle.toStringAsFixed(0)}°',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSequenceCard(dynamic seq) {
    final isPlaying = widget.presetService.isPlayingSequence;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                seq.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (isPlaying) {
                    widget.presetService.stopSequence();
                  } else {
                    widget.presetService.runSequence(seq, widget.robotController);
                  }
                },
                icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow, size: 18),
                label: Text(isPlaying ? 'Stop' : 'Run Demo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPlaying ? AppColors.emergencyRed : AppColors.statusGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${seq.steps.length} coordinated choreography steps',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
