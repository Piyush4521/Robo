import '../../models/joint.dart';

class JointValidationResult {
  final bool isValid;
  final int jointId;
  final String jointName;
  final double requestedAngle;
  final double safeMin;
  final double safeMax;
  final String? reason;

  const JointValidationResult({
    required this.isValid,
    required this.jointId,
    required this.jointName,
    required this.requestedAngle,
    required this.safeMin,
    required this.safeMax,
    this.reason,
  });

  factory JointValidationResult.valid(Joint joint, double requested) {
    return JointValidationResult(
      isValid: true,
      jointId: joint.id,
      jointName: joint.name,
      requestedAngle: requested,
      safeMin: joint.safeMin,
      safeMax: joint.safeMax,
    );
  }

  factory JointValidationResult.invalid(Joint joint, double requested, String reason) {
    return JointValidationResult(
      isValid: false,
      jointId: joint.id,
      jointName: joint.name,
      requestedAngle: requested,
      safeMin: joint.safeMin,
      safeMax: joint.safeMax,
      reason: reason,
    );
  }
}

class PoseValidationReport {
  final bool allValid;
  final List<JointValidationResult> jointResults;

  const PoseValidationReport({
    required this.allValid,
    required this.jointResults,
  });

  String get summaryError {
    final invalid = jointResults.where((r) => !r.isValid);
    if (invalid.isEmpty) return '';
    return invalid.map((r) => '${r.jointName}: ${r.reason}').join(', ');
  }
}

class TargetValidator {
  static JointValidationResult validateSingleJoint(Joint joint, double? requested) {
    if (requested == null) {
      return JointValidationResult.invalid(joint, 0, 'Target angle is missing');
    }
    if (requested.isNaN) {
      return JointValidationResult.invalid(joint, requested, 'Value is NaN');
    }
    if (requested.isInfinite) {
      return JointValidationResult.invalid(joint, requested, 'Value is Infinite');
    }
    if (requested < joint.safeMin) {
      return JointValidationResult.invalid(
        joint,
        requested,
        'Below safe min (${joint.safeMin.toStringAsFixed(0)}°)',
      );
    }
    if (requested > joint.safeMax) {
      return JointValidationResult.invalid(
        joint,
        requested,
        'Above safe max (${joint.safeMax.toStringAsFixed(0)}°)',
      );
    }
    return JointValidationResult.valid(joint, requested);
  }

  static PoseValidationReport validatePose(List<Joint> joints, List<double> targetAngles) {
    if (targetAngles.length != joints.length) {
      return PoseValidationReport(
        allValid: false,
        jointResults: [
          for (int i = 0; i < joints.length; i++)
            JointValidationResult.invalid(joints[i], 0, 'Pose length mismatch')
        ],
      );
    }

    final results = <JointValidationResult>[];
    bool valid = true;

    for (int i = 0; i < joints.length; i++) {
      final res = validateSingleJoint(joints[i], targetAngles[i]);
      results.add(res);
      if (!res.isValid) {
        valid = false;
      }
    }

    return PoseValidationReport(allValid: valid, jointResults: results);
  }
}
