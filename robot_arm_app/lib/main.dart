import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_colors.dart';
import 'bluetooth/bluetooth_manager.dart';
import 'controllers/robot_controller.dart';
import 'services/preset_service.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/control/control_screen.dart';
import 'screens/pose/pose_screen.dart';
import 'screens/saved/saved_screen.dart';
import 'screens/settings/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final bluetoothManager = BluetoothManager();
  final robotController = RobotController(bluetoothManager: bluetoothManager);
  final presetService = PresetService();

  runApp(RobotArmApp(
    robotController: robotController,
    presetService: presetService,
  ));
}

class RobotArmApp extends StatelessWidget {
  final RobotController robotController;
  final PresetService presetService;

  const RobotArmApp({
    super.key,
    required this.robotController,
    required this.presetService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROBOT ARM - 6-DOF Controller',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: RootNavigationContainer(
        robotController: robotController,
        presetService: presetService,
      ),
    );
  }
}

class RootNavigationContainer extends StatefulWidget {
  final RobotController robotController;
  final PresetService presetService;

  const RootNavigationContainer({
    super.key,
    required this.robotController,
    required this.presetService,
  });

  @override
  State<RootNavigationContainer> createState() => _RootNavigationContainerState();
}

class _RootNavigationContainerState extends State<RootNavigationContainer> {
  bool _showSplash = true;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return SplashScreen(
        onFinish: () {
          setState(() {
            _showSplash = false;
          });
        },
      );
    }

    final screens = [
      HomeScreen(
        robotController: widget.robotController,
        onNavigateToTab: (index) => setState(() => _currentIndex = index),
        onOpenSettings: () => setState(() => _currentIndex = 3),
      ),
      ControlScreen(
        robotController: widget.robotController,
        onSwitchToAnglesMode: () => setState(() => _currentIndex = 2), // switch to Pose tab
      ),
      PoseScreen(
        robotController: widget.robotController,
      ),
      SettingsScreen(
        robotController: widget.robotController,
      ),
      SavedScreen(
        robotController: widget.robotController,
        presetService: widget.presetService,
      ),
    ];

    // Note: Tab indexing:
    // 0: Home
    // 1: Control (Gamepad)
    // 2: Poses (Database)
    // 3: Settings (Gear)

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          screens[0], // Home
          screens[1], // Control
          screens[2], // Pose
          screens[3], // Settings
          screens[4], // Saved Poses
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 1.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: AppColors.primary.withValues(alpha: 0.12),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                );
              }
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: AppColors.primary, size: 24);
              }
              return const IconThemeData(color: AppColors.textSecondary, size: 24);
            }),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex > 3 ? 2 : _currentIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _currentIndex = idx;
              });
            },
            backgroundColor: AppColors.surface,
            elevation: 0,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports_rounded),
                label: 'Control',
              ),
              NavigationDestination(
                icon: Icon(Icons.storage_outlined),
                selectedIcon: Icon(Icons.storage_rounded),
                label: 'Poses',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
