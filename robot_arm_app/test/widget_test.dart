import 'package:flutter_test/flutter_test.dart';
import 'package:robot_arm_app/bluetooth/command_protocol.dart';
import 'package:robot_arm_app/bluetooth/bluetooth_manager.dart';
import 'package:robot_arm_app/core/safety/target_validator.dart';
import 'package:robot_arm_app/models/joint.dart';
import 'package:robot_arm_app/controllers/robot_controller.dart';
import 'package:robot_arm_app/services/preset_service.dart';
import 'package:robot_arm_app/main.dart';

void main() {
  group('TargetValidator Tests', () {
    final joints = Joint.defaultJoints();

    test('Validates safe target within boundaries', () {
      final baseJoint = joints[0]; // Min: 0, Max: 180
      final result = TargetValidator.validateSingleJoint(baseJoint, 90.0);
      expect(result.isValid, isTrue);
    });

    test('Rejects target below safe minimum', () {
      final shoulderJoint = joints[1]; // Min: 15, Max: 165
      final result = TargetValidator.validateSingleJoint(shoulderJoint, 10.0);
      expect(result.isValid, isFalse);
      expect(result.reason, contains('Below safe min'));
    });

    test('Rejects target above safe maximum', () {
      final elbowJoint = joints[2]; // Min: 20, Max: 160
      final result = TargetValidator.validateSingleJoint(elbowJoint, 175.0);
      expect(result.isValid, isFalse);
      expect(result.reason, contains('Above safe max'));
    });

    test('Rejects NaN and null targets', () {
      final wristJoint = joints[4];
      final resNull = TargetValidator.validateSingleJoint(wristJoint, null);
      final resNaN = TargetValidator.validateSingleJoint(wristJoint, double.nan);
      expect(resNull.isValid, isFalse);
      expect(resNaN.isValid, isFalse);
    });
  });

  group('CommandProtocol Protocol Tests', () {
    test('Encodes standard handshake commands correctly', () {
      expect(CommandProtocol.buildHello(), equals('HELLO\n'));
      expect(CommandProtocol.buildStatusQuery(), equals('STATUS?\n'));
      expect(CommandProtocol.buildReadyAck(), equals('READY_ACK\n'));
      expect(CommandProtocol.buildStop(), equals('STOP\n'));
      expect(CommandProtocol.buildEstop(), equals('ESTOP\n'));
      expect(CommandProtocol.buildResetEstop(), equals('RESET_ESTOP\n'));
      expect(CommandProtocol.buildHome(), equals('HOME\n'));
    });

    test('Encodes joint jog and pose commands correctly', () {
      expect(CommandProtocol.buildJogPositive(0), equals('J+:0\n'));
      expect(CommandProtocol.buildJogNegative(1), equals('J-:1\n'));
      expect(CommandProtocol.buildJogStop(2), equals('J0:2\n'));
      expect(CommandProtocol.buildSpeed(3), equals('SPD:3\n'));
      expect(
        CommandProtocol.buildPose([90.0, 75.0, 110.0, 90.0, 85.0, 28.0]),
        equals('POSE:90.0,75.0,110.0,90.0,85.0,28.0\n'),
      );
    });

    test('Buffers and reconstructs fragmented chunks correctly', () {
      final protocol = CommandProtocol();
      final chunk1 = 'ROBOT_6DOF_';
      final chunk2 = 'READY v1\nSTATE:';
      final chunk3 = 'READY\n';

      final lines1 = protocol.processIncomingChunk(chunk1);
      expect(lines1, isEmpty);

      final lines2 = protocol.processIncomingChunk(chunk2);
      expect(lines2, equals(['ROBOT_6DOF_READY v1']));

      final lines3 = protocol.processIncomingChunk(chunk3);
      expect(lines3, equals(['STATE:READY']));
    });
  });

  group('App Widget Smoke Tests', () {
    testWidgets('RobotArmApp boots and displays initial launch header', (tester) async {
      final bluetoothManager = BluetoothManager();
      final robotController = RobotController(bluetoothManager: bluetoothManager);
      final presetService = PresetService();

      await tester.pumpWidget(RobotArmApp(
        robotController: robotController,
        presetService: presetService,
      ));

      expect(find.text('ROBOT ARM'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });
  });
}
