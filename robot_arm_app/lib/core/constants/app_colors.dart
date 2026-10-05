import 'package:flutter/material.dart';

class AppColors {
  // Backgrounds
  static const Color background = Color(0xFFF4F8FC);
  static const Color backgroundLight = Color(0xFFFAFCFF);
  static const Color backgroundDarker = Color(0xFFE9F1FA);
  
  // Surfaces & Cards
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF0F5FA);
  static const Color border = Color(0xFFE2EAF4);
  static const Color borderFocused = Color(0xFF007AFF);
  
  // Brand & Accents
  static const Color primary = Color(0xFF007AFF);
  static const Color primaryDark = Color(0xFF0056B3);
  static const Color cyanAccent = Color(0xFF00C2FF);
  static const Color primaryGlow = Color(0x33007AFF);

  // Safety & Emergency
  static const Color emergencyRed = Color(0xFFFF3B30);
  static const Color emergencyDark = Color(0xFFD70015);
  static const Color emergencyGlow = Color(0x40FF3B30);

  // Status & Telemetry
  static const Color statusGreen = Color(0xFF34C759);
  static const Color statusYellow = Color(0xFFFF9500);
  static const Color statusRed = Color(0xFFFF3B30);
  static const Color statusBlue = Color(0xFF007AFF);
  
  // Typography
  static const Color textPrimary = Color(0xFF0F1E36);
  static const Color textSecondary = Color(0xFF5A6B82);
  static const Color textMuted = Color(0xFF8E9EB5);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Joint Distinctive Palette (from Reference Design)
  static const Color jointBase = Color(0xFF007AFF);      // Blue
  static const Color jointShoulder = Color(0xFF34C759);  // Green
  static const Color jointElbow = Color(0xFFFF9500);     // Amber
  static const Color jointLowerArm = Color(0xFFAF52DE);  // Purple
  static const Color jointWrist = Color(0xFFFF453A);     // Coral
  static const Color jointGripper = Color(0xFF30B0C7);   // Cyan/Slate
  
  // Joystick & Interactive Controls
  static const Color joystickBase = Color(0xFFE5EFF9);
  static const Color joystickHandle = Color(0xFF007AFF);
  static const Color joystickHandleHighlight = Color(0xFF40A9FF);
  static const Color controlActive = Color(0xFF007AFF);
  static const Color controlInactive = Color(0xFFD3E1F0);
}
