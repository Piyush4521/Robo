class CommandProtocol {
  // Encoders
  static String buildHello() => 'HELLO\n';
  static String buildStatusQuery() => 'STATUS?\n';
  static String buildReadyAck() => 'READY_ACK\n';
  static String buildPing() => 'PING\n';
  
  static String buildSelectJoint(int jointId) => 'SEL:$jointId\n';
  static String buildSpeed(int speedProfile) => 'SPD:$speedProfile\n';
  
  static String buildJogPositive(int jointId) => 'J+:$jointId\n';
  static String buildJogNegative(int jointId) => 'J-:$jointId\n';
  static String buildJogStop([int? jointId]) => jointId != null ? 'J0:$jointId\n' : 'J0\n';
  
  static String buildPose(List<double> angles) {
    final anglesStr = angles.map((a) => a.toStringAsFixed(1)).join(',');
    return 'POSE:$anglesStr\n';
  }
  
  static String buildMove() => 'MOVE\n';
  static String buildStop() => 'STOP\n';
  static String buildEstop() => 'ESTOP\n';
  static String buildResetEstop() => 'RESET_ESTOP\n';
  static String buildHome() => 'HOME\n';
  static String buildCalibQuery() => 'CALIB?\n';

  // Decoders / Line Buffer
  final StringBuffer _rxBuffer = StringBuffer();

  List<String> processIncomingChunk(String chunk) {
    final lines = <String>[];
    _rxBuffer.write(chunk);
    
    final content = _rxBuffer.toString();
    final parts = content.split('\n');

    // The last part is either incomplete or empty
    for (int i = 0; i < parts.length - 1; i++) {
      final line = parts[i].trim();
      if (line.isNotEmpty) {
        lines.add(line);
      }
    }

    _rxBuffer.clear();
    _rxBuffer.write(parts.last);

    return lines;
  }
}
