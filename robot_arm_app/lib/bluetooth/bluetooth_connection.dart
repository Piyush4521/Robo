import 'dart:async';
import 'package:flutter/services.dart';

abstract class IBluetoothConnection {
  Stream<String> get incomingDataStream;
  bool get isConnected;
  Future<void> send(String data);
  Future<void> disconnect();
}

class NativeAndroidBluetoothConnection implements IBluetoothConnection {
  static const MethodChannel _methodChannel =
      MethodChannel('com.robotarm.controller/bluetooth');
  static const EventChannel _eventChannel =
      EventChannel('com.robotarm.controller/bluetooth_stream');

  final StreamController<String> _streamController =
      StreamController<String>.broadcast();
  StreamSubscription? _eventSub;
  bool _isConnected = false;

  NativeAndroidBluetoothConnection(String macAddress) {
    _init(macAddress);
  }

  Future<void> _init(String macAddress) async {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (data) {
        if (data is String) {
          _streamController.add(data);
        }
      },
      onError: (err) {
        _isConnected = false;
        _streamController.addError(err);
      },
      onDone: () {
        _isConnected = false;
      },
    );
  }

  static Future<bool> isBluetoothAvailable() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isBluetoothAvailable');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isBluetoothEnabled() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('isBluetoothEnabled');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasPermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('hasBluetoothPermissions');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> requestPermissions() async {
    try {
      final res = await _methodChannel.invokeMethod<bool>('requestBluetoothPermissions');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, String>>> getPairedDevices() async {
    try {
      final res = await _methodChannel.invokeListMethod('getPairedDevices');
      if (res != null) {
        return res.map((item) => Map<String, String>.from(item as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<NativeAndroidBluetoothConnection?> connect(String address) async {
    try {
      final success = await _methodChannel.invokeMethod<bool>('connect', {'address': address});
      if (success == true) {
        final conn = NativeAndroidBluetoothConnection(address);
        conn._isConnected = true;
        return conn;
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  @override
  Stream<String> get incomingDataStream => _streamController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> send(String data) async {
    if (!_isConnected) return;
    try {
      await _methodChannel.invokeMethod('send', {'data': data});
    } catch (e) {
      _isConnected = false;
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    await _eventSub?.cancel();
    try {
      await _methodChannel.invokeMethod('disconnect');
    } catch (_) {}
    _streamController.close();
  }
}

class SimulatedBluetoothConnection implements IBluetoothConnection {
  final StreamController<String> _controller = StreamController<String>.broadcast();
  bool _connected = true;

  @override
  Stream<String> get incomingDataStream => _controller.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> send(String data) async {
    if (!_connected) return;
    final trimmed = data.trim();

    await Future.delayed(const Duration(milliseconds: 15));

    if (trimmed == 'HELLO') {
      _controller.add('ROBOT_6DOF_READY v1\n');
    } else if (trimmed == 'STATUS?') {
      _controller.add('STATE:READY,MOTION:IDLE,SPD:2,ANGLES:92.0,75.0,110.0,90.0,85.0,28.0\n');
    } else if (trimmed == 'READY_ACK') {
      _controller.add('OK\n');
    } else if (trimmed.startsWith('SPD:')) {
      _controller.add('ACK:$trimmed\n');
    } else if (trimmed.startsWith('SEL:')) {
      _controller.add('ACK:$trimmed\n');
    } else if (trimmed.startsWith('J+:') || trimmed.startsWith('J-:')) {
      _controller.add('ACK:$trimmed\n');
    } else if (trimmed.startsWith('J0')) {
      _controller.add('ACK:J0\n');
    } else if (trimmed.startsWith('POSE:')) {
      _controller.add('ACK:POSE\n');
    } else if (trimmed == 'MOVE') {
      _controller.add('ACK:MOVE\n');
      _controller.add('STATE:READY,MOTION:MOVING_TO_TARGET,SPD:2,ANGLES:92.0,75.0,110.0,90.0,85.0,28.0\n');
    } else if (trimmed == 'STOP') {
      _controller.add('ACK:STOP\n');
      _controller.add('STATE:STOPPED,MOTION:IDLE,SPD:2,ANGLES:92.0,75.0,110.0,90.0,85.0,28.0\n');
    } else if (trimmed == 'ESTOP') {
      _controller.add('ACK:ESTOP\n');
      _controller.add('STATE:ESTOP,MOTION:IDLE,SPD:2,ANGLES:92.0,75.0,110.0,90.0,85.0,28.0\n');
    } else if (trimmed == 'RESET_ESTOP') {
      _controller.add('ACK:RESET_ESTOP\n');
      _controller.add('STATE:STOPPED,MOTION:IDLE,SPD:2,ANGLES:92.0,75.0,110.0,90.0,85.0,28.0\n');
    } else if (trimmed == 'HOME') {
      _controller.add('ACK:HOME\n');
    } else if (trimmed == 'PING') {
      _controller.add('PONG\n');
    }
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _controller.close();
  }
}
