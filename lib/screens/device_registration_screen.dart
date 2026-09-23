import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/device_service.dart';
import '../services/firebase_service.dart';
import 'device_selection_screen.dart';
import 'login_screen.dart';

class DeviceRegistrationScreen extends StatefulWidget {
  const DeviceRegistrationScreen({super.key});

  @override
  State<DeviceRegistrationScreen> createState() => _DeviceRegistrationScreenState();
}

class _DeviceRegistrationScreenState extends State<DeviceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _registerDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final code = _codeController.text.trim();
    final name = _nameController.text.trim();

    // Validate if the device code exists in Firebase
    final isValid = await DeviceService().validateDeviceCode(code);

    if (!mounted) return;

    if (isValid) {
      // Register device locally
      await DeviceService().registerDevice(code, name);
      
      if (!mounted) return;
      
      // Navigate to Selection screen (which handles redirecting to Dashboard if needed)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DeviceSelectionScreen()),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid device code. Could not connect to the ESP32.';
      });
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Device'),
        leading: Navigator.canPop(context) ? null : const SizedBox.shrink(),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.textMuted),
            tooltip: 'Sign Out',
            onPressed: _signOut,
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.water_drop, color: AppColors.accent, size: 64);
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Connect a Device',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the device code provided with your hardware to begin monitoring.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                
                // Device Code Field
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Device Code',
                    hintText: 'e.g., ESP32-A1B2C3',
                    prefixIcon: const Icon(Icons.qr_code, color: AppColors.accent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a device code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Device Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Device Name (Optional)',
                    hintText: 'e.g., Pond 1 - Tilapia',
                    prefixIcon: const Icon(Icons.label, color: AppColors.accent),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      // Provide a default name if empty
                      _nameController.text = 'Unnamed Device';
                    }
                    return null;
                  },
                ),
                
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.alertPumpFault.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.alertPumpFault),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.alertPumpFault),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.alertPumpFault),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 48),
                
                // Register Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _registerDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textPrimary,
                          ),
                        )
                      : const Text(
                          'Register Device',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
