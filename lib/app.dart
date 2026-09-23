import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/log_screen.dart';
import 'screens/device_selection_screen.dart';

class MainShell extends StatefulWidget {
  final String deviceCode;
  final String deviceName;

  const MainShell({
    super.key,
    required this.deviceCode,
    required this.deviceName,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
    DashboardScreen(
      deviceCode: widget.deviceCode,
      deviceName: widget.deviceName,
      onBackToDevices: _goBackToDeviceList,
    ),
    LogScreen(deviceCode: widget.deviceCode),
  ];

  void _goBackToDeviceList() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DeviceSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}
