import 'dart:math';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// 3D Vector for kinematic rendering
class Vector3D {
  final double x;
  final double y;
  final double z;

  const Vector3D(this.x, this.y, this.z);

  Vector3D operator +(Vector3D o) => Vector3D(x + o.x, y + o.y, z + o.z);
  Vector3D operator -(Vector3D o) => Vector3D(x - o.x, y - o.y, z - o.z);
  Vector3D operator *(double s) => Vector3D(x * s, y * s, z * s);

  double dot(Vector3D o) => x * o.x + y * o.y + z * o.z;

  Vector3D cross(Vector3D o) => Vector3D(
        y * o.z - z * o.y,
        z * o.x - x * o.z,
        x * o.y - y * o.x,
      );

  double get length => sqrt(x * x + y * y + z * z);

  Vector3D normalized() {
    final len = length;
    if (len < 1e-6) return const Vector3D(0, 1, 0);
    return Vector3D(x / len, y / len, z / len);
  }
}

/// Perspective projected 3D kinematic model of a 6-DOF industrial robot arm
class Robot3DModelWidget extends StatefulWidget {
  final List<double> angles; // 6 angles in degrees: [Base, Shoulder, Elbow, WristPitch, WristRoll, Gripper]
  final double height;
  final bool showControls;

  const Robot3DModelWidget({
    super.key,
    required this.angles,
    this.height = 230,
    this.showControls = true,
  });

  @override
  State<Robot3DModelWidget> createState() => _Robot3DModelWidgetState();
}

class _Robot3DModelWidgetState extends State<Robot3DModelWidget> {
  // Camera angles in radians
  double _azimuth = 0.65; // ~37 degrees horizontal orbit
  double _elevation = 0.35; // ~20 degrees vertical tilt
  double _zoom = 1.0;
  int _viewPreset = 0; // 0: Iso, 1: Front, 2: Side, 3: Top

  void _resetCamera() {
    setState(() {
      _azimuth = 0.65;
      _elevation = 0.35;
      _zoom = 1.0;
      _viewPreset = 0;
    });
  }

  void _setPreset(int preset) {
    setState(() {
      _viewPreset = preset;
      switch (preset) {
        case 0: // Isometric
          _azimuth = 0.65;
          _elevation = 0.35;
          break;
        case 1: // Front
          _azimuth = 0.0;
          _elevation = 0.15;
          break;
        case 2: // Side (Right)
          _azimuth = pi / 2;
          _elevation = 0.15;
          break;
        case 3: // Top Down
          _azimuth = 0.0;
          _elevation = 1.45; // ~83 degrees
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we have exactly 6 valid joint angles with defaults
    final safeAngles = List<double>.generate(6, (i) {
      if (i < widget.angles.length && !widget.angles[i].isNaN) {
        return widget.angles[i];
      }
      return 90.0;
    });

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E293B), // Slate 800
            Color(0xFF0B1120), // Deep Dark
          ],
        ),
        border: Border.all(color: const Color(0xFF334155), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Interactive 3D Canvas
            GestureDetector(
              onScaleUpdate: (details) {
                setState(() {
                  if (details.scale != 1.0) {
                    _zoom = (_zoom * details.scale).clamp(0.6, 1.8);
                  } else {
                    _azimuth += details.focalPointDelta.dx * 0.012;
                    _elevation = (_elevation - details.focalPointDelta.dy * 0.012)
                        .clamp(-0.1, 1.48);
                  }
                });
              },
              onDoubleTap: _resetCamera,
              child: CustomPaint(
                size: Size.infinite,
                painter: _Robot3DKinematicsPainter(
                  angles: safeAngles,
                  azimuth: _azimuth,
                  elevation: _elevation,
                  zoom: _zoom,
                ),
              ),
            ),

            // Top-left: Real-time Synchronized 6-DOF Status Badge
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xCC0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.cyanAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.statusGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.statusGreen.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '3D KINEMATICS: B${safeAngles[0].toInt()}° S${safeAngles[1].toInt()}° E${safeAngles[2].toInt()}°',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom-left: End Effector & Gripper Status
            Positioned(
              bottom: 12,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'WRIST: P${safeAngles[3].toInt()}° R${safeAngles[4].toInt()}° | CLAW: ${safeAngles[5].toInt()}°',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),

            // Floating Camera Dock (Top Right)
            if (widget.showControls)
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xDD1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF475569)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDockButton(Icons.view_in_ar_rounded, 'Iso', 0),
                      _buildDockButton(Icons.stay_current_landscape, 'Front', 1),
                      _buildDockButton(Icons.swap_horiz_rounded, 'Side', 2),
                      _buildDockButton(Icons.fullscreen_exit_rounded, 'Top', 3),
                      const Divider(height: 1, color: Color(0xFF334155)),
                      IconButton(
                        icon: const Icon(Icons.restart_alt_rounded, size: 18, color: AppColors.cyanAccent),
                        tooltip: 'Reset Camera View',
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        onPressed: _resetCamera,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockButton(IconData icon, String label, int preset) {
    final isSelected = _viewPreset == preset;
    return InkWell(
      onTap: () => _setPreset(preset),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.cyanAccent : const Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

/// Custom 3D Projection Painter for the 6-DOF Robotic Arm
class _Robot3DKinematicsPainter extends CustomPainter {
  final List<double> angles;
  final double azimuth;
  final double elevation;
  final double zoom;

  _Robot3DKinematicsPainter({
    required this.angles,
    required this.azimuth,
    required this.elevation,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height * 0.62;
    const focalLength = 380.0;
    const cameraDistance = 480.0;

    // Projection function from 3D world coordinates to 2D screen coordinates
    Offset project(Vector3D v) {
      // 1. Orbit around Y axis (azimuth)
      final x1 = v.x * cos(azimuth) - v.z * sin(azimuth);
      final z1 = v.x * sin(azimuth) + v.z * cos(azimuth);
      final y1 = v.y;

      // 2. Tilt around X axis (elevation)
      final y2 = y1 * cos(elevation) - z1 * sin(elevation);
      final z2 = y1 * sin(elevation) + z1 * cos(elevation);
      final x2 = x1;

      // 3. Perspective projection
      final d = cameraDistance + z2;
      final scale = (focalLength / max(d, 40.0)) * zoom;

      return Offset(
        centerX + x2 * scale,
        centerY - y2 * scale,
      );
    }

    // 1. Draw 3D Ground Grid & Turntable Base
    _drawGroundGrid(canvas, project);

    // 2. Calculate 6-DOF Forward Kinematics
    // Dimensions in mm
    const baseHeight = 28.0;
    const link1Len = 85.0; // Upper Arm
    const link2Len = 80.0; // Forearm
    const link3Len = 38.0; // Wrist to Claw Flange
    const fingerLen = 24.0; // Gripper claws

    // Joint angles in radians
    // Base: 0 to 180 deg, centered at 90 deg
    final thBase = (angles[0] - 90.0) * pi / 180.0;
    // Shoulder: 15 to 165 deg (90 is straight vertical)
    final thShoulder = angles[1] * pi / 180.0;
    // Elbow: relative bend to shoulder
    final thElbowRel = (angles[2] - 90.0) * pi / 180.0;
    final thElbowAbs = thShoulder + thElbowRel - (pi / 2);
    // Wrist Pitch:
    final thWristRel = (angles[3] - 90.0) * pi / 180.0;
    final thWristAbs = thElbowAbs + thWristRel - (pi / 2);
    // Wrist Roll:
    final thWristRoll = (angles[4] - 90.0) * pi / 180.0;
    // Gripper claw opening: 0 (closed) to 180 (fully open)
    final clawSpread = 4.0 + 16.0 * (angles[5].clamp(0.0, 180.0) / 180.0);

    // Joint Positions in 3D:
    // P0: Base center on ground
    const p0 = Vector3D(0, 0, 0);
    // P1: Turntable / Shoulder joint
    const p1 = Vector3D(0, baseHeight, 0);

    // Unit direction in horizontal plane for arm reach:
    final cosBase = cos(thBase);
    final sinBase = sin(thBase);

    // Vector along link 1 (Shoulder to Elbow):
    final link1Dir = Vector3D(
      cos(thShoulder) * sinBase,
      sin(thShoulder),
      cos(thShoulder) * cosBase,
    );
    final p2 = p1 + link1Dir * link1Len; // Elbow

    // Vector along link 2 (Elbow to Wrist):
    final link2Dir = Vector3D(
      cos(thElbowAbs) * sinBase,
      sin(thElbowAbs),
      cos(thElbowAbs) * cosBase,
    );
    final p3 = p2 + link2Dir * link2Len; // Wrist

    // Vector along link 3 (Wrist to Tool Flange):
    final link3Dir = Vector3D(
      cos(thWristAbs) * sinBase,
      sin(thWristAbs),
      cos(thWristAbs) * cosBase,
    );
    final p4 = p3 + link3Dir * link3Len; // Tool Flange

    // Gripper finger cross vector (perpendicular to tool direction and rolled by WristRoll):
    final upRef = const Vector3D(0, 1, 0);
    var normalCross = link3Dir.cross(upRef).normalized();
    if (normalCross.length < 0.1) {
      normalCross = link3Dir.cross(const Vector3D(1, 0, 0)).normalized();
    }
    // Rotate cross vector by Wrist Roll angle:
    final binormal = link3Dir.cross(normalCross).normalized();
    final clawSpanVec = normalCross * cos(thWristRoll) + binormal * sin(thWristRoll);

    final pClawLeftBase = p4 - clawSpanVec * clawSpread;
    final pClawRightBase = p4 + clawSpanVec * clawSpread;
    final pClawLeftTip = pClawLeftBase + link3Dir * fingerLen - clawSpanVec * 3.0;
    final pClawRightTip = pClawRightBase + link3Dir * fingerLen + clawSpanVec * 3.0;

    // 3. Render Arm Segments & Joints with depth and industrial aesthetics

    // Base Pedestal
    _drawCylinder(canvas, project, p0, p1, radius: 24, color: const Color(0xFF1E293B));
    _drawJointRing(canvas, project, p1, radius: 18, color: AppColors.cyanAccent);

    // Link 1: Upper Arm (Carbon grey with metallic accents)
    _drawArmBeam(canvas, project, p1, p2, width: 14, color: const Color(0xFF334155), accentColor: AppColors.primary);
    _drawJointPod(canvas, project, p1, radius: 14, label: 'J1');

    // Link 2: Forearm
    _drawArmBeam(canvas, project, p2, p3, width: 11, color: const Color(0xFF475569), accentColor: AppColors.cyanAccent);
    _drawJointPod(canvas, project, p2, radius: 12, label: 'J2');

    // Link 3: Wrist
    _drawArmBeam(canvas, project, p3, p4, width: 8, color: const Color(0xFF64748B), accentColor: Colors.amber);
    _drawJointPod(canvas, project, p3, radius: 9, label: 'J3');

    // Flange & Gripper Jaws
    _drawJointRing(canvas, project, p4, radius: 8, color: const Color(0xFFCBD5E1));
    _drawGripperClaw(canvas, project, p4, pClawLeftBase, pClawLeftTip, pClawRightBase, pClawRightTip);
  }

  void _drawGroundGrid(Canvas canvas, Offset Function(Vector3D) project) {
    final gridPaint = Paint()
      ..color = const Color(0x3338BDF8)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final axisPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Radial distance circles on floor
    for (double r = 40.0; r <= 160.0; r += 40.0) {
      final path = Path();
      for (int i = 0; i <= 36; i++) {
        final ang = i * (2 * pi / 36);
        final pt = project(Vector3D(cos(ang) * r, 0, sin(ang) * r));
        if (i == 0) {
          path.moveTo(pt.dx, pt.dy);
        } else {
          path.lineTo(pt.dx, pt.dy);
        }
      }
      canvas.drawPath(path, gridPaint);
    }

    // Grid cross lines
    const extent = 160.0;
    canvas.drawLine(project(const Vector3D(-extent, 0, 0)), project(const Vector3D(extent, 0, 0)), axisPaint..color = const Color(0x44EF4444)); // X red
    canvas.drawLine(project(const Vector3D(0, 0, -extent)), project(const Vector3D(0, 0, extent)), axisPaint..color = const Color(0x443B82F6)); // Z blue
  }

  void _drawCylinder(Canvas canvas, Offset Function(Vector3D) project, Vector3D bottom, Vector3D top, {required double radius, required Color color}) {
    final ptB = project(bottom);
    final ptT = project(top);

    final paintBody = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final paintStroke = Paint()
      ..color = const Color(0xFF475569)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromCenter(
      center: Offset((ptB.dx + ptT.dx) / 2, (ptB.dy + ptT.dy) / 2),
      width: radius * 2 * zoom,
      height: (ptB.dy - ptT.dy).abs() + 8,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, paintBody);
    canvas.drawRRect(rrect, paintStroke);
  }

  void _drawArmBeam(Canvas canvas, Offset Function(Vector3D) project, Vector3D from, Vector3D to, {required double width, required Color color, required Color accentColor}) {
    final pF = project(from);
    final pT = project(to);

    final paintMain = Paint()
      ..color = color
      ..strokeWidth = width * zoom
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintAccent = Paint()
      ..color = accentColor.withValues(alpha: 0.85)
      ..strokeWidth = (width * 0.35) * zoom
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(pF, pT, paintMain);
    canvas.drawLine(pF, pT, paintAccent);
  }

  void _drawJointPod(Canvas canvas, Offset Function(Vector3D) project, Vector3D pos, {required double radius, required String label}) {
    final pt = project(pos);
    final r = radius * zoom;

    final paintFill = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final paintRim = Paint()
      ..color = AppColors.cyanAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(pt, r, paintFill);
    canvas.drawCircle(pt, r, paintRim);

    // Glowing center dot
    canvas.drawCircle(
      pt,
      r * 0.4,
      Paint()..color = Colors.white..style = PaintingStyle.fill,
    );
  }

  void _drawJointRing(Canvas canvas, Offset Function(Vector3D) project, Vector3D pos, {required double radius, required Color color}) {
    final pt = project(pos);
    final r = radius * zoom;
    canvas.drawCircle(
      pt,
      r,
      Paint()
        ..color = color.withValues(alpha: 0.6)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawGripperClaw(
    Canvas canvas,
    Offset Function(Vector3D) project,
    Vector3D flange,
    Vector3D clawLBase,
    Vector3D clawLTip,
    Vector3D clawRBase,
    Vector3D clawRTip,
  ) {
    final pFlange = project(flange);
    final pLB = project(clawLBase);
    final pLT = project(clawLTip);
    final pRB = project(clawRBase);
    final pRT = project(clawRTip);

    final clawPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 3.5 * zoom
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final tipPaint = Paint()
      ..color = AppColors.emergencyRed
      ..strokeWidth = 4.5 * zoom
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Crossbar from flange to claw bases
    canvas.drawLine(pLB, pRB, clawPaint);
    canvas.drawLine(pFlange, pLB, clawPaint);
    canvas.drawLine(pFlange, pRB, clawPaint);

    // Left and right fingers
    canvas.drawLine(pLB, pLT, clawPaint);
    canvas.drawLine(pRB, pRT, clawPaint);

    // Rubber grip pads on tips
    canvas.drawCircle(pLT, 2.5 * zoom, tipPaint);
    canvas.drawCircle(pRT, 2.5 * zoom, tipPaint);
  }

  @override
  bool shouldRepaint(covariant _Robot3DKinematicsPainter old) {
    if (old.azimuth != azimuth || old.elevation != elevation || old.zoom != zoom) {
      return true;
    }
    if (old.angles.length != angles.length) return true;
    for (int i = 0; i < angles.length; i++) {
      if ((old.angles[i] - angles[i]).abs() > 0.01) return true;
    }
    return false;
  }
}
