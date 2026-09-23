import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';
import 'device_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'Initializing...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _status = 'Connecting to Firebase...');
      await FirebaseService().initialize();
      
      // Add a slight delay for visual branding
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;
      
      // Check if user is logged in
      final user = FirebaseService().currentUser;
      
      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DeviceSelectionScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'Initialization Failed';
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo Placeholder (using an icon for now)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.water_drop, color: AppColors.accent, size: 48);
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'SaliSense',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Automated Salinity Monitoring',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 48),
            if (_hasError)
              Column(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.alertPumpFault),
                  const SizedBox(height: 8),
                  Text(_status, style: const TextStyle(color: AppColors.alertPumpFault)),
                ],
              )
            else
              Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_status, style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
