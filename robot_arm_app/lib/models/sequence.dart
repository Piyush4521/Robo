import 'robot_pose.dart';

class SequenceStep {
  final RobotPose pose;
  final int durationMs;
  final int delayMs;
  final String description;

  const SequenceStep({
    required this.pose,
    this.durationMs = 1200,
    this.delayMs = 400,
    this.description = '',
  });
}

class RobotSequence {
  final String id;
  final String name;
  final List<SequenceStep> steps;

  const RobotSequence({
    required this.id,
    required this.name,
    required this.steps,
  });

  static List<RobotSequence> defaultSequences() {
    final presets = RobotPose.defaultPresets();
    return [
      RobotSequence(
        id: 'seq_pick_place',
        name: 'Pick & Place Standard Demo',
        steps: [
          SequenceStep(pose: presets[0], description: 'Move to Home'),
          SequenceStep(pose: presets[1], description: 'Approach target block'),
          SequenceStep(pose: presets[2], description: 'Grip & lift payload'),
          SequenceStep(pose: presets[3], description: 'Move to target placement zone'),
          SequenceStep(pose: presets[0], description: 'Return to Home'),
        ],
      )
    ];
  }
}
