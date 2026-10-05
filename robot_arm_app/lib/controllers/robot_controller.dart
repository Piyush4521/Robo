import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/robot_state.dart';
import '../models/joint.dart';
import '../bluetooth/bluetooth_manager.dart';
import '../bluetooth/command_protocol.dart';
import '../core/safety/target_validator.dart';

class RobotController extends ChangeNotifier {
  final BluetoothManager bluetoothManager;
  late RobotState _state;
  StreamSubscription? _lineSub;
  StreamSubscription? _statusSub;

  int _lastCommandTime = 0;
  static const int _rateLimitMs = 50; // Max 20 commands/second

  RobotController({required this.bluetoothManager}) {
    _state = RobotState.initial();

    // Listen to bluetooth status changes
    _statusSub = bluetoothManager.statusStream.listen((status) {
      _state = _state.copyWith(
        connectionState: status,
        robotReady: (status == ConnectionStatus.connected),
        connectedDeviceName: bluetoothManager.connectedDeviceName,
      );
      notifyListeners();
    });

    // Listen to incoming protocol lines
    _lineSub = bluetoothManager.incomingLinesStream.listen(_handleIncomingLine);
  }

  RobotState get state => _state;
  List<Joint> get joints => _state.joints;
  bool get isReady => _state.robotReady && !_state.emergencyStopped;

  void _handleIncomingLine(String line) {
    if (line.startsWith('STATE:')) {
      _parseStateLine(line);
    } else if (line == 'ACK:STOP') {
      _state = _state.copyWith(
        motionState: MotionStatus.stopped,
      );
      notifyListeners();
    } else if (line == 'ACK:ESTOP') {
      _state = _state.copyWith(
        emergencyStopped: true,
        motionState: MotionStatus.estop,
        robotReady: false,
      );
      notifyListeners();
    } else if (line == 'ACK:RESET_ESTOP') {
      _state = _state.copyWith(
        emergencyStopped: false,
        motionState: MotionStatus.idle,
        robotReady: true,
      );
      notifyListeners();
    } else if (line.startsWith('ERR:')) {
      _state = _state.copyWith(lastError: line);
      notifyListeners();
    }
  }

  void _parseStateLine(String line) {
    // Format: STATE:<state>,MOTION:<motion>,SPD:<spd>,ANGLES:<b,s,e,l,w,g>
    final parts = line.split(',');
    for (final part in parts) {
      if (part.startsWith('ANGLES:')) {
        final anglesStr = part.substring(7);
        final angleList = anglesStr.split(',').map((s) => double.tryParse(s.trim()) ?? 90.0).toList();
        if (angleList.length >= 6) {
          final updatedJoints = <Joint>[];
          for (int i = 0; i < 6; i++) {
            updatedJoints.add(_state.joints[i].copyWith(
              commandedAngle: angleList[i],
            ));
          }
          _state = _state.copyWith(joints: updatedJoints);
          notifyListeners();
        }
      }
    }
  }

  // Speed Profile
  Future<void> setSpeed(int speed) async {
    if (speed < 1 || speed > 3) return;
    _state = _state.copyWith(speedProfile: speed);
    notifyListeners();
    await bluetoothManager.send(CommandProtocol.buildSpeed(speed));
  }

  // Board Profile
  void setBoardProfile(String boardName) {
    _state = _state.copyWith(boardProfileName: boardName);
    notifyListeners();
  }

  // Select Joint for Fine Control
  Future<void> selectJoint(int jointId) async {
    if (jointId < 0 || jointId >= _state.joints.length) return;
    _state = _state.copyWith(selectedJoint: jointId);
    notifyListeners();
    await bluetoothManager.send(CommandProtocol.buildSelectJoint(jointId));
  }

  // Momentary Jog Controls (Press/Hold)
  Future<void> startJogPositive(int jointId) async {
    if (!isReady) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCommandTime < _rateLimitMs) return;
    _lastCommandTime = now;

    _state = _state.copyWith(motionState: MotionStatus.manual);
    // Smoothly update local commanded angle for instant tactile feedback
    _jogLocal(jointId, 1.2);
    notifyListeners();

    await bluetoothManager.send(CommandProtocol.buildJogPositive(jointId));
  }

  Future<void> startJogNegative(int jointId) async {
    if (!isReady) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCommandTime < _rateLimitMs) return;
    _lastCommandTime = now;

    _state = _state.copyWith(motionState: MotionStatus.manual);
    _jogLocal(jointId, -1.2);
    notifyListeners();

    await bluetoothManager.send(CommandProtocol.buildJogNegative(jointId));
  }

  Future<void> stopJog(int jointId) async {
    _state = _state.copyWith(motionState: MotionStatus.idle);
    notifyListeners();
    await bluetoothManager.send(CommandProtocol.buildJogStop(jointId));
  }

  void _jogLocal(int jointId, double delta) {
    if (jointId < 0 || jointId >= _state.joints.length) return;
    final j = _state.joints[jointId];
    final updatedAngle = j.clampToLimits(j.commandedAngle + delta);
    final updatedList = List<Joint>.from(_state.joints);
    updatedList[jointId] = j.copyWith(commandedAngle: updatedAngle, targetAngle: updatedAngle);
    _state = _state.copyWith(joints: updatedList);
  }

  // Direct Gripper Control
  Future<void> setGripperAngle(double angle) async {
    if (!isReady) return;
    final gripperJoint = _state.joints[5];
    final clamped = gripperJoint.clampToLimits(angle);

    final updatedList = List<Joint>.from(_state.joints);
    updatedList[5] = gripperJoint.copyWith(commandedAngle: clamped, targetAngle: clamped);
    _state = _state.copyWith(joints: updatedList);
    notifyListeners();

    final targets = updatedList.map((j) => j.commandedAngle).toList();
    await bluetoothManager.send(CommandProtocol.buildPose(targets));
    await bluetoothManager.send(CommandProtocol.buildMove());
  }

  // Update target angle (without moving hardware yet)
  void updateTargetAngle(int jointId, double target) {
    if (jointId < 0 || jointId >= _state.joints.length) return;
    final j = _state.joints[jointId];
    final updated = j.copyWith(targetAngle: target);
    final updatedList = List<Joint>.from(_state.joints);
    updatedList[jointId] = updated;
    _state = _state.copyWith(joints: updatedList);
    notifyListeners();
  }

  // Move to Staged Targets
  Future<bool> moveToTargetPose() async {
    if (!isReady) return false;

    // Validate targets before sending
    final report = TargetValidator.validatePose(
      _state.joints,
      _state.targetAngles,
    );

    if (!report.allValid) {
      _state = _state.copyWith(lastError: report.summaryError);
      notifyListeners();
      return false;
    }

    _state = _state.copyWith(motionState: MotionStatus.movingToTarget);
    notifyListeners();

    // 1. Send POSE command
    await bluetoothManager.send(CommandProtocol.buildPose(_state.targetAngles));
    // 2. Send MOVE command
    await bluetoothManager.send(CommandProtocol.buildMove());

    // Smoothly animate current commanded angles towards target for realistic visualization
    _interpolateTowardsTarget();
    return true;
  }

  void _interpolateTowardsTarget() {
    Timer.periodic(const Duration(milliseconds: 30), (timer) {
      bool allReached = true;
      final updatedList = <Joint>[];

      for (int i = 0; i < _state.joints.length; i++) {
        final j = _state.joints[i];
        final diff = j.targetAngle - j.commandedAngle;
        if (diff.abs() > 0.5) {
          allReached = false;
          final step = (diff * 0.15).clamp(-2.0, 2.0);
          updatedList.add(j.copyWith(commandedAngle: j.commandedAngle + step));
        } else {
          updatedList.add(j.copyWith(commandedAngle: j.targetAngle));
        }
      }

      _state = _state.copyWith(
        joints: updatedList,
        motionState: allReached ? MotionStatus.idle : MotionStatus.movingToTarget,
      );
      notifyListeners();

      if (allReached || _state.motionState == MotionStatus.stopped || _state.emergencyStopped) {
        timer.cancel();
      }
    });
  }

  // Home Position
  Future<void> moveToHome() async {
    if (!isReady) return;
    _state = _state.copyWith(motionState: MotionStatus.homing);
    notifyListeners();

    // Set target angles to safe home
    final updatedList = <Joint>[];
    for (final j in _state.joints) {
      updatedList.add(j.copyWith(targetAngle: j.safeHome));
    }
    _state = _state.copyWith(joints: updatedList);
    notifyListeners();

    await bluetoothManager.send(CommandProtocol.buildHome());
    _interpolateTowardsTarget();
  }

  // Update Joint Calibration (from Settings)
  void updateJointCalibration(int jointId, {double? safeMin, double? safeMax, double? safeHome, double? offset}) {
    if (jointId < 0 || jointId >= _state.joints.length) return;
    final j = _state.joints[jointId];
    final updated = j.copyWith(
      safeMin: safeMin ?? j.safeMin,
      safeMax: safeMax ?? j.safeMax,
      safeHome: safeHome ?? j.safeHome,
      offset: offset ?? j.offset,
    );
    final updatedList = List<Joint>.from(_state.joints);
    updatedList[jointId] = updated;
    _state = _state.copyWith(joints: updatedList);
    notifyListeners();
  }

  // Persistent STOP ALL
  Future<void> stopAll() async {
    _state = _state.copyWith(
      motionState: MotionStatus.stopped,
    );
    notifyListeners();
    await bluetoothManager.send(CommandProtocol.buildStop());
  }

  // EMERGENCY STOP
  Future<void> emergencyStop() async {
    _state = _state.copyWith(
      emergencyStopped: true,
      motionState: MotionStatus.estop,
      robotReady: false,
    );
    notifyListeners();
    await bluetoothManager.send(CommandProtocol.buildEstop());
  }

  // Clear Emergency Stop
  Future<void> resetEmergencyStop() async {
    await bluetoothManager.send(CommandProtocol.buildResetEstop());
    _state = _state.copyWith(
      emergencyStopped: false,
      motionState: MotionStatus.idle,
      robotReady: true,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _lineSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
