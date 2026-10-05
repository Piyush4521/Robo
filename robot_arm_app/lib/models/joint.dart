class Joint {
  final int id;
  final String name;
  final int channel;
  final String servoType;
  final double safeMin;
  final double safeMax;
  final double safeHome;
  final double offset;
  final double commandedAngle; // Open-loop last commanded angle, not measured
  final double targetAngle;

  const Joint({
    required this.id,
    required this.name,
    required this.channel,
    required this.servoType,
    required this.safeMin,
    required this.safeMax,
    required this.safeHome,
    required this.offset,
    required this.commandedAngle,
    required this.targetAngle,
  });

  bool isWithinLimits(double angle) {
    return angle >= safeMin && angle <= safeMax;
  }

  double clampToLimits(double angle) {
    if (angle < safeMin) return safeMin;
    if (angle > safeMax) return safeMax;
    return angle;
  }

  Joint copyWith({
    int? id,
    String? name,
    int? channel,
    String? servoType,
    double? safeMin,
    double? safeMax,
    double? safeHome,
    double? offset,
    double? commandedAngle,
    double? targetAngle,
  }) {
    return Joint(
      id: id ?? this.id,
      name: name ?? this.name,
      channel: channel ?? this.channel,
      servoType: servoType ?? this.servoType,
      safeMin: safeMin ?? this.safeMin,
      safeMax: safeMax ?? this.safeMax,
      safeHome: safeHome ?? this.safeHome,
      offset: offset ?? this.offset,
      commandedAngle: commandedAngle ?? this.commandedAngle,
      targetAngle: targetAngle ?? this.targetAngle,
    );
  }

  static List<Joint> defaultJoints() {
    return const [
      Joint(
        id: 0,
        name: 'Base',
        channel: 0,
        servoType: 'MG995',
        safeMin: 0,
        safeMax: 180,
        safeHome: 90,
        offset: 0,
        commandedAngle: 92,
        targetAngle: 92,
      ),
      Joint(
        id: 1,
        name: 'Shoulder',
        channel: 1,
        servoType: 'MG996R',
        safeMin: 15,
        safeMax: 165,
        safeHome: 75,
        offset: 0,
        commandedAngle: 75,
        targetAngle: 75,
      ),
      Joint(
        id: 2,
        name: 'Elbow',
        channel: 2,
        servoType: 'MG996R',
        safeMin: 20,
        safeMax: 160,
        safeHome: 110,
        offset: 0,
        commandedAngle: 110,
        targetAngle: 110,
      ),
      Joint(
        id: 3,
        name: 'Lower Arm',
        channel: 3,
        servoType: 'SG90',
        safeMin: 10,
        safeMax: 170,
        safeHome: 90,
        offset: 0,
        commandedAngle: 90,
        targetAngle: 90,
      ),
      Joint(
        id: 4,
        name: 'Wrist',
        channel: 4,
        servoType: 'SG90',
        safeMin: 0,
        safeMax: 180,
        safeHome: 85,
        offset: 0,
        commandedAngle: 85,
        targetAngle: 85,
      ),
      Joint(
        id: 5,
        name: 'Gripper',
        channel: 5,
        servoType: 'SG90',
        safeMin: 10,
        safeMax: 90,
        safeHome: 28,
        offset: 0,
        commandedAngle: 28,
        targetAngle: 28,
      ),
    ];
  }
}
