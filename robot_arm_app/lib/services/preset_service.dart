import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/robot_pose.dart';
import '../models/sequence.dart';
import '../controllers/robot_controller.dart';

class PresetService extends ChangeNotifier {
  final List<RobotPose> _savedPoses = [];
  final List<RobotSequence> _sequences = [];
  bool _isPlayingSequence = false;

  PresetService() {
    _savedPoses.addAll(RobotPose.defaultPresets());
    _sequences.addAll(RobotSequence.defaultSequences());
  }

  List<RobotPose> get savedPoses => List.unmodifiable(_savedPoses);
  List<RobotSequence> get sequences => List.unmodifiable(_sequences);
  bool get isPlayingSequence => _isPlayingSequence;

  void saveCurrentPose(String name, String description, List<double> currentAngles) {
    final newPose = RobotPose(
      id: 'pose_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      angles: List.from(currentAngles),
      createdAt: DateTime.now(),
    );
    _savedPoses.add(newPose);
    notifyListeners();
  }

  void deletePose(String id) {
    _savedPoses.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  Future<void> runSequence(RobotSequence sequence, RobotController robotController) async {
    if (_isPlayingSequence || !robotController.isReady) return;
    _isPlayingSequence = true;
    notifyListeners();

    try {
      for (final step in sequence.steps) {
        if (!_isPlayingSequence || robotController.state.emergencyStopped) break;

        // Stage targets
        for (int i = 0; i < step.pose.angles.length; i++) {
          robotController.updateTargetAngle(i, step.pose.angles[i]);
        }

        // Execute move
        await robotController.moveToTargetPose();
        await Future.delayed(Duration(milliseconds: step.durationMs + step.delayMs));
      }
    } finally {
      _isPlayingSequence = false;
      notifyListeners();
    }
  }

  void stopSequence() {
    _isPlayingSequence = false;
    notifyListeners();
  }
}
