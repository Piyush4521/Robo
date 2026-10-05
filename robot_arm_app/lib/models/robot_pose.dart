class RobotPose {
  final String id;
  final String name;
  final List<double> angles; // 6 joint angles: Base, Shoulder, Elbow, Lower Arm, Wrist, Gripper
  final String description;
  final DateTime createdAt;

  const RobotPose({
    required this.id,
    required this.name,
    required this.angles,
    this.description = '',
    required this.createdAt,
  });

  static List<RobotPose> defaultPresets() {
    return [
      RobotPose(
        id: 'pose_home',
        name: 'Home Position',
        description: 'Safe calibrated baseline stance',
        angles: [90.0, 75.0, 110.0, 90.0, 85.0, 28.0],
        createdAt: DateTime.now(),
      ),
      RobotPose(
        id: 'pose_pick',
        name: 'Pick Approach',
        description: 'Lower arm forward with gripper open',
        angles: [90.0, 45.0, 130.0, 110.0, 75.0, 80.0],
        createdAt: DateTime.now(),
      ),
      RobotPose(
        id: 'pose_lift',
        name: 'Payload Lift',
        description: 'Vertical lift with clamped gripper',
        angles: [90.0, 95.0, 90.0, 80.0, 85.0, 25.0],
        createdAt: DateTime.now(),
      ),
      RobotPose(
        id: 'pose_place',
        name: 'Drop Off Right',
        description: 'Base rotated 45° right for drop',
        angles: [135.0, 50.0, 125.0, 105.0, 80.0, 85.0],
        createdAt: DateTime.now(),
      ),
      RobotPose(
        id: 'pose_standby',
        name: 'Standby Rest',
        description: 'Compact folded park position',
        angles: [90.0, 25.0, 150.0, 150.0, 90.0, 20.0],
        createdAt: DateTime.now(),
      ),
    ];
  }
}
