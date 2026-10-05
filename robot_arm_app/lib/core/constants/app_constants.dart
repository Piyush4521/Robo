class AppConstants {
  static const String appName = 'ROBOT ARM';
  static const String appSubtitle = '6-DOF Controller';
  static const String appVersion = '1.0.0';
  static const String protocolVersion = 'v1';

  // Bluetooth HC-05 defaults
  static const String defaultDeviceName = 'HC-05';
  static const int defaultBaudRate = 9600;
  static const int connectionTimeoutMs = 5000;
  static const int heartbeatIntervalMs = 800;
  static const int safetyTimeoutMs = 1500;

  // Rate limiting for Bluetooth transmission (Hz)
  static const int manualCommandRateLimitMs = 60; // Max ~16 commands/sec to avoid serial buffer overflow

  // Joystick defaults
  static const double joystickDeadZone = 0.15;
  static const double joystickMaxOutput = 1.0;

  // Joint identifiers
  static const int jointBase = 0;
  static const int jointShoulder = 1;
  static const int jointElbow = 2;
  static const int jointLowerArm = 3;
  static const int jointWrist = 4;
  static const int jointGripper = 5;

  // Speed Profiles
  static const int speedSlow = 1;
  static const int speedNormal = 2;
  static const int speedFast = 3;
}
