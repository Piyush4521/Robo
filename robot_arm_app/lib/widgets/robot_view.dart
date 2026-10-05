import 'package:flutter/material.dart';
import 'robot_3d_renderer.dart';

class Robot3DView extends StatelessWidget {
  final List<double> angles; // 6 angles: [Base, Shoulder, Elbow, WristPitch, WristRoll, Gripper]
  final double height;
  final bool showControls;

  const Robot3DView({
    super.key,
    required this.angles,
    this.height = 230,
    this.showControls = true,
  });

  @override
  Widget build(BuildContext context) {
    return Robot3DModelWidget(
      angles: angles,
      height: height,
      showControls: showControls,
    );
  }
}
