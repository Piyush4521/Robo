import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/robot_controller.dart';
import '../../bluetooth/bluetooth_manager.dart';
import '../../models/robot_state.dart';

class SettingsScreen extends StatefulWidget {
  final RobotController robotController;

  const SettingsScreen({super.key, required this.robotController});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final List<String> _consoleLogs = [];
  bool _showConsole = true;
  bool _isLoadingDevices = false;
  String? _connectingAddress;
  List<BluetoothDeviceItem> _pairedDevices = [];
  final TextEditingController _customMacCtrl = TextEditingController();
  final TextEditingController _cmdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.robotController.bluetoothManager.rawLogsStream.listen((log) {
      if (mounted) {
        setState(() {
          _consoleLogs.add(log);
          if (_consoleLogs.length > 60) _consoleLogs.removeAt(0);
        });
      }
    });

    // Auto-fetch paired devices on screen load
    _refreshDevices();
  }

  @override
  void dispose() {
    _customMacCtrl.dispose();
    _cmdCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final devices = await widget.robotController.bluetoothManager.getPairedDevices();
      if (mounted) {
        setState(() {
          _pairedDevices = devices;
          _isLoadingDevices = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingDevices = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await widget.robotController.bluetoothManager.requestPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted ? 'Bluetooth permissions granted!' : 'Permissions not granted. Please check phone settings.'),
          backgroundColor: granted ? AppColors.statusGreen : AppColors.emergencyRed,
        ),
      );
      if (granted) {
        _refreshDevices();
      }
    }
  }

  Future<void> _connectToDevice(BluetoothDeviceItem device) async {
    setState(() => _connectingAddress = device.address);
    final success = await widget.robotController.bluetoothManager.connect(device);
    if (mounted) {
      setState(() => _connectingAddress = null);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect to ${device.name} [${device.address}]'),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
    }
  }

  void _showEditLimitsDialog(int jointId) {
    final joint = widget.robotController.state.joints[jointId];
    final minCtrl = TextEditingController(text: joint.safeMin.toStringAsFixed(0));
    final maxCtrl = TextEditingController(text: joint.safeMax.toStringAsFixed(0));
    final homeCtrl = TextEditingController(text: joint.safeHome.toStringAsFixed(0));
    final offsetCtrl = TextEditingController(text: joint.offset.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Edit ${joint.name} Limits & Calibration'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SAFETY NOTICE: Mechanical limits must be verified on the physical arm to prevent gear binding or servo stall.',
                  style: TextStyle(fontSize: 11, color: AppColors.emergencyRed, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Safe Minimum Angle (deg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Safe Maximum Angle (deg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: homeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Safe Home Pose Angle (deg)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: offsetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calibration Offset (deg)', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final minVal = double.tryParse(minCtrl.text.trim()) ?? joint.safeMin;
                final maxVal = double.tryParse(maxCtrl.text.trim()) ?? joint.safeMax;
                final homeVal = double.tryParse(homeCtrl.text.trim()) ?? joint.safeHome;
                final offsetVal = double.tryParse(offsetCtrl.text.trim()) ?? joint.offset;

                widget.robotController.updateJointCalibration(
                  jointId,
                  safeMin: minVal,
                  safeMax: maxVal,
                  safeHome: homeVal,
                  offset: offsetVal,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Save & Apply'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.robotController,
      builder: (context, _) {
        final state = widget.robotController.state;
        final isConnected = state.connectionState == ConnectionStatus.connected;
        final isConnecting = state.connectionState == ConnectionStatus.connecting;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Settings & Setup',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Hardware calibration, HC-05 paired devices & link telemetry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Bluetooth Connection Center Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title & Connection Status Pill
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: (isConnected ? AppColors.statusGreen : AppColors.primary)
                                        .withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.bluetooth_searching,
                                    color: isConnected ? AppColors.statusGreen : AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Bluetooth Classic (HC-05)',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      isConnected
                                          ? 'Connected to ${state.connectedDeviceName ?? "HC-05"}'
                                          : (isConnecting ? 'Connecting...' : 'Disconnected'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isConnected
                                            ? AppColors.statusGreen
                                            : (isConnecting ? Colors.orange : AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            // Quick Disconnect or Permissions button
                            if (isConnected)
                              ElevatedButton(
                                onPressed: () => widget.robotController.bluetoothManager.disconnect(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emergencyRed,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: const Size(0, 32),
                                ),
                                child: const Text('Disconnect', style: TextStyle(fontSize: 12)),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: _requestPermissions,
                                icon: const Icon(Icons.security, size: 14),
                                label: const Text('Permissions', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: const Size(0, 32),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Scan / Refresh Button Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Paired Bluetooth Devices',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                            ),
                            TextButton.icon(
                              onPressed: _isLoadingDevices ? null : _refreshDevices,
                              icon: _isLoadingDevices
                                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh, size: 16),
                              label: const Text('Scan / Refresh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Devices List
                        if (_isLoadingDevices)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        else if (_pairedDevices.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text('No Paired Devices Found', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  '1. Open your Android Settings -> Bluetooth.\n2. Pair with HC-05 (Default PIN: 1234 or 0000).\n3. Return here and tap "Scan / Refresh".',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: _pairedDevices.map((device) {
                              final isCurrent = isConnected && state.connectedDeviceName == device.name;
                              final isThisConnecting = _connectingAddress == device.address;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCurrent ? AppColors.statusGreen : AppColors.border,
                                    width: isCurrent ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.bluetooth,
                                                size: 16,
                                                color: isCurrent ? AppColors.statusGreen : AppColors.primary,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  device.name,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            device.address,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontFamily: 'monospace',
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrent)
                                      ElevatedButton(
                                        onPressed: () => widget.robotController.bluetoothManager.disconnect(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.emergencyRed,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: const Size(0, 32),
                                        ),
                                        child: const Text('Disconnect', style: TextStyle(fontSize: 11)),
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: isThisConnecting ? null : () => _connectToDevice(device),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          minimumSize: const Size(0, 32),
                                        ),
                                        child: isThisConnecting
                                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                            : const Text('Connect', style: TextStyle(fontSize: 11)),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 10),

                        // Manual Direct MAC Connect Option
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customMacCtrl,
                                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                decoration: InputDecoration(
                                  hintText: 'Direct MAC (e.g. 98:D3:31:F4:2B:12)',
                                  hintStyle: const TextStyle(fontSize: 11),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                final mac = _customMacCtrl.text.trim();
                                if (mac.isNotEmpty) {
                                  _connectToDevice(BluetoothDeviceItem(name: 'HC-05 Custom', address: mac));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF334155),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Connect MAC', style: TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Terminal toggle
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'ASCII Protocol Monitor',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                            ),
                            Row(
                              children: [
                                if (_consoleLogs.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18),
                                    onPressed: () => setState(() => _consoleLogs.clear()),
                                    tooltip: 'Clear Logs',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: _showConsole,
                                  onChanged: (val) => setState(() => _showConsole = val),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (_showConsole) ...[
                          Container(
                            height: 120,
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListView.builder(
                              itemCount: _consoleLogs.length,
                              reverse: true,
                              itemBuilder: (context, index) {
                                final log = _consoleLogs[_consoleLogs.length - 1 - index];
                                final isTx = log.startsWith('TX:');
                                final isErr = log.startsWith('ERR:') || log.startsWith('WARN:');
                                return Text(
                                  log,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                    color: isErr
                                        ? const Color(0xFFF87171)
                                        : (isTx ? const Color(0xFF38BDF8) : const Color(0xFF4ADE80)),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Custom Command Sender
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _cmdCtrl,
                                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  decoration: InputDecoration(
                                    hintText: 'Send Command (e.g. HELLO, STATUS?, PARK)',
                                    hintStyle: const TextStyle(fontSize: 11),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ElevatedButton(
                                onPressed: isConnected
                                    ? () {
                                        final cmd = _cmdCtrl.text.trim();
                                        if (cmd.isNotEmpty) {
                                          widget.robotController.bluetoothManager.send(cmd);
                                          _cmdCtrl.clear();
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Send', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Controller Board Profile Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Arduino Controller Board Profile',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'The protocol remains identical across boards. Select your physical board:',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: state.boardProfileName,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Arduino UNO R3', child: Text('Arduino UNO R3 (A4/A5 I2C, SoftSerial 10/11)')),
                            DropdownMenuItem(value: 'Arduino Nano (ATmega328P)', child: Text('Arduino Nano (A4/A5 I2C, SoftSerial 10/11)')),
                            DropdownMenuItem(value: 'Arduino Mega 2560', child: Text('Arduino Mega 2560 (20/21 I2C, Serial1 18/19)')),
                          ],
                          onChanged: (val) {
                            if (val != null) widget.robotController.setBoardProfile(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. Calibration & Joint Limits Table
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Joint Limits & Calibration',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Tap joint to edit',
                              style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(state.joints.length, (i) {
                          final j = state.joints[i];
                          return InkWell(
                            onTap: () => _showEditLimitsDialog(i),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'J${i + 1}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        j.name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        'Range: ${j.safeMin.toInt()}° - ${j.safeMax.toInt()}°',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
