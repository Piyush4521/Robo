import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class DualAxisJoystick extends StatefulWidget {
  final String title;
  final String upLabel;
  final String downLabel;
  final String leftLabel;
  final String rightLabel;
  final Function(double x, double y) onDirectionChanged;
  final VoidCallback onReleased;
  final ValueChanged<bool>? onDragStateChanged;
  final double radius;

  const DualAxisJoystick({
    super.key,
    required this.title,
    required this.upLabel,
    required this.downLabel,
    required this.leftLabel,
    required this.rightLabel,
    required this.onDirectionChanged,
    required this.onReleased,
    this.onDragStateChanged,
    this.radius = 65.0,
  });

  @override
  State<DualAxisJoystick> createState() => _DualAxisJoystickState();
}

class _DualAxisJoystickState extends State<DualAxisJoystick> {
  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;

  void _updatePosition(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = localPosition - center;
    final distance = delta.distance;
    final maxDist = widget.radius;

    Offset clampedOffset;
    if (distance > maxDist) {
      clampedOffset = Offset.fromDirection(delta.direction, maxDist);
    } else {
      clampedOffset = delta;
    }

    if (!_isDragging) {
      widget.onDragStateChanged?.call(true);
    }

    setState(() {
      _dragPosition = clampedOffset;
      _isDragging = true;
    });

    // Normalize to -1.0 to +1.0
    final normalizedX = (clampedOffset.dx / maxDist).clamp(-1.0, 1.0);
    final normalizedY = (-clampedOffset.dy / maxDist).clamp(-1.0, 1.0); // Up is positive

    widget.onDirectionChanged(normalizedX, normalizedY);
  }

  void _onPanEnd() {
    if (_isDragging) {
      widget.onDragStateChanged?.call(false);
    }
    setState(() {
      _dragPosition = Offset.zero;
      _isDragging = false;
    });
    widget.onReleased();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Direction Up
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_arrow_up, size: 18, color: AppColors.primary),
              const SizedBox(width: 2),
              Text(
                widget.upLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Middle row: Left, Center Joystick, Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left Label
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.keyboard_arrow_left, size: 18, color: AppColors.primary),
                  Text(
                    widget.leftLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),

              // Interactive Joystick Pad with raw gesture listener
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (details) => _updatePosition(
                  details.localPosition,
                  Size(widget.radius * 2, widget.radius * 2),
                ),
                onPanUpdate: (details) => _updatePosition(
                  details.localPosition,
                  Size(widget.radius * 2, widget.radius * 2),
                ),
                onPanEnd: (_) => _onPanEnd(),
                onPanCancel: () => _onPanEnd(),
                child: Container(
                  width: widget.radius * 2,
                  height: widget.radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFE9F4FF),
                        Color(0xFFD6EBFF),
                        Color(0xFFC3E0FA),
                      ],
                      stops: [0.0, 0.7, 1.0],
                    ),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Subtle tactile circular track
                      Container(
                        width: widget.radius * 1.15,
                        height: widget.radius * 1.15,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),
                      // Center Thumb Knob
                      Transform.translate(
                        offset: _dragPosition,
                        child: AnimatedContainer(
                          duration: _isDragging
                              ? Duration.zero
                              : const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF339AF0), Color(0xFF007AFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.38),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right Label
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.rightLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_right, size: 18, color: AppColors.primary),
                ],
              ),
            ],
          ),
          const SizedBox(height: 2),

          // Direction Down
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.primary),
              const SizedBox(width: 2),
              Text(
                widget.downLabel,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
