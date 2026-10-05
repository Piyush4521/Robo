import 'joint.dart';

enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  handshaking,
  connected,
  error,
}

enum MotionStatus {
  idle,
  manual,
  movingToTarget,
  homing,
  stopped,
  estop,
  error,
}

class RobotState {
  final ConnectionStatus connectionState;
  final bool robotReady;
  final bool emergencyStopped;
  final MotionStatus motionState;
  final List<Joint> joints;
  final int speedProfile; // 1: Slow, 2: Normal, 3: Fast
  final int selectedJoint; // 0..5
  final String? lastError;
  final String? connectedDeviceName;
  final String boardProfileName;

  const RobotState({
    this.connectionState = ConnectionStatus.disconnected,
    this.robotReady = false,
    this.emergencyStopped = false,
    this.motionState = MotionStatus.idle,
    required this.joints,
    this.speedProfile = 2,
    this.selectedJoint = 0,
    this.lastError,
    this.connectedDeviceName,
    this.boardProfileName = 'Arduino UNO R3',
  });

  List<double> get currentCommandedAngles =>
      joints.map((j) => j.commandedAngle).toList();

  List<double> get targetAngles =>
      joints.map((j) => j.targetAngle).toList();

  RobotState copyWith({
    ConnectionStatus? connectionState,
    bool? robotReady,
    bool? emergencyStopped,
    MotionStatus? motionState,
    List<Joint>? joints,
    int? speedProfile,
    int? selectedJoint,
    String? lastError,
    String? connectedDeviceName,
    String? boardProfileName,
  }) {
    return RobotState(
      connectionState: connectionState ?? this.connectionState,
      robotReady: robotReady ?? this.robotReady,
      emergencyStopped: emergencyStopped ?? this.emergencyStopped,
      motionState: motionState ?? this.motionState,
      joints: joints ?? this.joints,
      speedProfile: speedProfile ?? this.speedProfile,
      selectedJoint: selectedJoint ?? this.selectedJoint,
      lastError: lastError,
      connectedDeviceName: connectedDeviceName ?? this.connectedDeviceName,
      boardProfileName: boardProfileName ?? this.boardProfileName,
    );
  }

  factory RobotState.initial() {
    return RobotState(
      connectionState: ConnectionStatus.disconnected,
      robotReady: false,
      emergencyStopped: false,
      motionState: MotionStatus.idle,
      joints: Joint.defaultJoints(),
      speedProfile: 2,
      selectedJoint: 0,
      connectedDeviceName: null,
      boardProfileName: 'Arduino UNO R3',
    );
  }
}
