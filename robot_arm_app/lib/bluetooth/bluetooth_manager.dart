import 'dart:async';
import 'dart:io' show Platform;
import '../models/robot_state.dart';
import 'bluetooth_connection.dart';
import 'command_protocol.dart';

class BluetoothDeviceItem {
  final String name;
  final String address;
  final bool isPaired;

  const BluetoothDeviceItem({
    required this.name,
    required this.address,
    this.isPaired = true,
  });
}

class BluetoothManager {
  final CommandProtocol _protocol = CommandProtocol();
  IBluetoothConnection? _connection;
  StreamSubscription? _incomingSub;

  final StreamController<ConnectionStatus> _statusController =
      StreamController<ConnectionStatus>.broadcast();
  final StreamController<String> _rawLogsController =
      StreamController<String>.broadcast();
  final StreamController<String> _linesController =
      StreamController<String>.broadcast();

  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  String? _connectedDeviceName;

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<String> get rawLogsStream => _rawLogsController.stream;
  Stream<String> get incomingLinesStream => _linesController.stream;
  ConnectionStatus get currentStatus => _currentStatus;
  String? get connectedDeviceName => _connectedDeviceName;

  void _setStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      try {
        final granted = await NativeAndroidBluetoothConnection.requestPermissions();
        if (!granted) {
          _rawLogsController.add('WARN: Bluetooth permissions not granted');
        }
        return granted;
      } catch (e) {
        _rawLogsController.add('ERR: Permission request failed: $e');
        return false;
      }
    }
    return true;
  }

  Future<List<BluetoothDeviceItem>> getPairedDevices() async {
    // 1. On real Android device, query the phone's bonded Bluetooth devices
    if (Platform.isAndroid) {
      try {
        final hasPerms = await NativeAndroidBluetoothConnection.hasPermissions();
        if (!hasPerms) {
          _rawLogsController.add('Requesting Bluetooth permissions from system...');
          await NativeAndroidBluetoothConnection.requestPermissions();
        }

        final list = await NativeAndroidBluetoothConnection.getPairedDevices();
        if (list.isNotEmpty) {
          _rawLogsController.add('Found ${list.length} paired Bluetooth device(s)');
          return list.map((d) => BluetoothDeviceItem(
            name: d['name'] ?? 'HC-05 Module',
            address: d['address'] ?? '',
          )).toList();
        } else {
          _rawLogsController.add('Notice: No paired Bluetooth devices found in Android Settings');
        }
      } catch (e) {
        _rawLogsController.add('Notice: Error fetching Android devices: $e');
      }
      return [];
    }

    // 2. On desktop/simulator only
    return const [
      BluetoothDeviceItem(name: 'Simulated HC-05 (Offline Test)', address: '00:00:00:00:00:00'),
    ];
  }

  Future<bool> connect(BluetoothDeviceItem device) async {
    _setStatus(ConnectionStatus.connecting);
    _rawLogsController.add('Connecting to ${device.name} [${device.address}]...');

    try {
      IBluetoothConnection conn;

      if (Platform.isAndroid && device.address != '00:00:00:00:00:00') {
        final nativeConn = await NativeAndroidBluetoothConnection.connect(device.address);
        if (nativeConn == null) {
          _setStatus(ConnectionStatus.error);
          _rawLogsController.add('ERR: Could not open RFCOMM SPP socket to ${device.address}');
          return false;
        }
        conn = nativeConn;
      } else {
        conn = SimulatedBluetoothConnection();
      }

      _connection = conn;
      _connectedDeviceName = device.name;

      _incomingSub = conn.incomingDataStream.listen(
        (chunk) {
          final lines = _protocol.processIncomingChunk(chunk);
          for (final line in lines) {
            _rawLogsController.add('RX: $line');
            _linesController.add(line);
          }
        },
        onError: (err) {
          _setStatus(ConnectionStatus.disconnected);
          _rawLogsController.add('ERR: Bluetooth stream error: $err');
        },
        onDone: () {
          _setStatus(ConnectionStatus.disconnected);
          _rawLogsController.add('Bluetooth link closed.');
        },
      );

      // Perform 3-step Handshake sequence
      _setStatus(ConnectionStatus.handshaking);
      _rawLogsController.add('Initiating Handshake: TX -> HELLO');

      final completer = Completer<bool>();
      late StreamSubscription lineSub;
      int handshakeStep = 0;

      lineSub = _linesController.stream.listen((line) {
        if (handshakeStep == 0 && line.contains('ROBOT_6DOF_READY')) {
          handshakeStep = 1;
          _rawLogsController.add('Handshake Step 1 OK. TX -> STATUS?');
          send(CommandProtocol.buildStatusQuery());
        } else if (handshakeStep == 1 && line.startsWith('STATE:')) {
          handshakeStep = 2;
          _rawLogsController.add('Handshake Step 2 OK. TX -> READY_ACK');
          send(CommandProtocol.buildReadyAck());
        } else if (handshakeStep == 2 && line == 'OK') {
          handshakeStep = 3;
          _rawLogsController.add('Handshake Step 3 Complete. Robot is READY!');
          lineSub.cancel();
          if (!completer.isCompleted) completer.complete(true);
        }
      });

      // Send initial HELLO
      await send(CommandProtocol.buildHello());

      // Timeout safety for handshake (5 seconds)
      final success = await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          lineSub.cancel();
          _rawLogsController.add('ERR: Handshake timed out.');
          return false;
        },
      );

      if (success) {
        _setStatus(ConnectionStatus.connected);
        return true;
      } else {
        _setStatus(ConnectionStatus.error);
        return false;
      }
    } catch (e) {
      _setStatus(ConnectionStatus.error);
      _rawLogsController.add('ERR: Connection exception: $e');
      return false;
    }
  }

  Future<void> send(String command) async {
    if (_connection != null && _connection!.isConnected) {
      _rawLogsController.add('TX: ${command.trim()}');
      await _connection!.send(command);
    }
  }

  Future<void> disconnect() async {
    _setStatus(ConnectionStatus.disconnected);
    await _incomingSub?.cancel();
    await _connection?.disconnect();
    _connection = null;
    _connectedDeviceName = null;
    _rawLogsController.add('Disconnected from robot.');
  }

  void dispose() {
    _incomingSub?.cancel();
    _connection?.disconnect();
    _statusController.close();
    _rawLogsController.close();
    _linesController.close();
  }
}
