import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import '../services/firebase_service.dart';
import '../app.dart';
import 'device_registration_screen.dart';
import 'login_screen.dart';

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  List<Device> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final devices = await DeviceService().getRegisteredDevices();
    setState(() {
      _devices = devices;
      _isLoading = false;
    });

    // If no devices are registered, redirect to registration screen
    if (_devices.isEmpty && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DeviceRegistrationScreen()),
      );
    }
  }

  Future<void> _selectDevice(Device device) async {
    await DeviceService().setActiveDevice(device.code);
    if (!mounted) return;
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainShell(
          deviceCode: device.code,
          deviceName: device.name,
        ),
      ),
    );
  }

  Future<void> _renameDevice(Device device) async {
    final controller = TextEditingController(text: device.name);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Rename Device', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'New Device Name',
            filled: true,
            fillColor: AppColors.background,
          ),
          style: const TextStyle(color: AppColors.textPrimary),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != device.name) {
      await DeviceService().renameDevice(device.code, newName);
      _loadDevices();
    }
  }

  Future<void> _removeDevice(Device device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Device', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Are you sure you want to remove "${device.name}"? You can add it back later using its code.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertPumpFault),
            child: const Text('Remove', style: TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DeviceService().removeDevice(device.code);
      _loadDevices();
    }
  }

  Future<void> _signOut() async {
    await FirebaseService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Devices'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textMuted),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _devices.length,
          itemBuilder: (context, index) {
            final device = _devices[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16.0),
              color: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16.0),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.water_drop, color: AppColors.accent, size: 24);
                      },
                    ),
                  ),
                ),
                title: Text(
                  device.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Code: ${device.code}',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                  color: AppColors.surface,
                  onSelected: (value) {
                    if (value == 'rename') {
                      _renameDevice(device);
                    } else if (value == 'remove') {
                      _removeDevice(device);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove', style: TextStyle(color: AppColors.alertPumpFault)),
                    ),
                  ],
                ),
                onTap: () => _selectDevice(device),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const DeviceRegistrationScreen()),
          );
        },
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add, color: AppColors.textPrimary),
        label: const Text('Add Device', style: TextStyle(color: AppColors.textPrimary)),
      ),
    );
  }
}
