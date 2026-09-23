import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/realtime_service.dart';
import '../services/firebase_service.dart';
import '../models/salinity_reading.dart';
import '../models/preset.dart';
import '../models/system_status.dart';
import '../models/alert.dart';
import '../widgets/salinity_gauge.dart';
import '../widgets/preset_card.dart';
import '../widgets/status_card.dart';
import '../widgets/alert_banner.dart';
import '../widgets/connection_indicator.dart';
import '../config/theme.dart';

class DashboardScreen extends StatefulWidget {
  final String deviceCode;
  final String deviceName;
  final VoidCallback? onBackToDevices;
  
  const DashboardScreen({
    super.key,
    required this.deviceCode,
    this.deviceName = 'Dashboard',
    this.onBackToDevices,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final RealtimeService _realtime;
  final FirebaseService _firebase = FirebaseService();

  @override
  void initState() {
    super.initState();
    _realtime = RealtimeService(deviceCode: widget.deviceCode);
  }

  // Cached last reading for offline state (Recommendation 5)
  SalinityReading? _lastReading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBackToDevices != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back to Devices',
                onPressed: widget.onBackToDevices,
              )
            : null,
        title: Text(widget.deviceName),
        actions: [
          StreamBuilder<bool>(
            stream: _firebase.connectionStateStream,
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: ConnectionIndicator(isConnected: isConnected),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.water_drop, color: AppColors.accent, size: 28);
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Alerts Area - Computed LOCALLY for 100% accuracy
            StreamBuilder<Preset>(
              stream: _realtime.streamActivePreset(),
              builder: (context, presetSnapshot) {
                return StreamBuilder<SalinityReading?>(
                  stream: _realtime.streamCurrentSalinity(),
                  builder: (context, readingSnapshot) {
                    return StreamBuilder<SystemStatus>(
                      stream: _realtime.streamSystemStatus(),
                      builder: (context, statusSnapshot) {
                        final preset = presetSnapshot.data;
                        final reading = readingSnapshot.data ?? _lastReading;
                        final status = statusSnapshot.data;

                        List<Alert> localAlerts = [];
                        
                        // 1. Overcorrection / Out of range alert (compare live reading to preset)
                        if (reading != null && preset != null && preset.name != 'Loading...' && preset.name != 'Error') {
                          if (reading.ppt < preset.minPpt) {
                            localAlerts.add(Alert(
                              type: AlertType.overcorrection,
                              message: 'Salinity too LOW: ${reading.ppt.toStringAsFixed(2)} ppt (min: ${preset.minPpt.toStringAsFixed(2)})',
                              timestamp: reading.timestamp,
                            ));
                          } else if (reading.ppt > preset.maxPpt) {
                            localAlerts.add(Alert(
                              type: AlertType.overcorrection,
                              message: 'Salinity too HIGH: ${reading.ppt.toStringAsFixed(2)} ppt (max: ${preset.maxPpt.toStringAsFixed(2)})',
                              timestamp: reading.timestamp,
                            ));
                          }
                        }
                        
                        // 2. Hardware faults
                        if (status != null) {
                          if (!status.isSensorHealthy) {
                            localAlerts.add(Alert(
                              type: AlertType.sensorFault,
                              message: 'Salinity sensor returned invalid reading. Check wiring.',
                              timestamp: DateTime.now(),
                            ));
                          }
                          if (status.isReservoirLow) {
                            localAlerts.add(Alert(
                              type: AlertType.lowReservoir,
                              message: 'Freshwater reservoir level is critically low.',
                              timestamp: DateTime.now(),
                            ));
                          }
                        }

                        // Slowly dissipate alerts that get resolved
                        return AnimatedSwitcher(
                          duration: const Duration(seconds: 2),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SizeTransition(
                                sizeFactor: animation,
                                axisAlignment: -1.0,
                                child: child,
                              ),
                            );
                          },
                          child: localAlerts.isEmpty 
                              ? const SizedBox.shrink(key: ValueKey('empty_alerts'))
                              : Column(
                                  key: ValueKey(localAlerts.map((a) => a.type.name).join('-')),
                                  children: localAlerts.map((alert) => AlertBanner(alert: alert)).toList(),
                                ),
                        );
                      },
                    );
                  },
                );
              },
            ),
            // Connection Status Alert if Offline
            StreamBuilder<bool>(
              stream: _firebase.connectionStateStream,
              builder: (context, snapshot) {
                final isConnected = snapshot.data ?? true; // assume connected while loading
                if (isConnected) return const SizedBox.shrink();
                
                String message = 'Reconnecting...';
                if (_lastReading != null) {
                  final timeStr = DateFormat('HH:mm:ss').format(_lastReading!.timestamp);
                  message = 'Showing last reading from $timeStr. Reconnecting...';
                }
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.offline.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.offline.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, 
                          color: AppColors.offline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Salinity Gauge & Active Preset
            StreamBuilder<Preset>(
              stream: _realtime.streamActivePreset(),
              builder: (context, presetSnapshot) {
                final preset = presetSnapshot.data;
                
                return StreamBuilder<SalinityReading?>(
                  stream: _realtime.streamCurrentSalinity(),
                  builder: (context, readingSnapshot) {
                    // Update cache if we get a new reading
                    if (readingSnapshot.hasData && readingSnapshot.data != null) {
                      _lastReading = readingSnapshot.data;
                    }
                    
                    // Use cache if offline/waiting
                    final currentReading = readingSnapshot.data ?? _lastReading;

                    return Column(
                      children: [
                        SalinityGauge(
                          reading: currentReading,
                          preset: preset,
                        ),
                        const SizedBox(height: 32),
                        PresetCard(preset: preset),
                      ],
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),

            // System Status
            StreamBuilder<SystemStatus>(
              stream: _realtime.streamSystemStatus(),
              builder: (context, snapshot) {
                final status = snapshot.data ?? SystemStatus();
                return StatusCard(status: status);
              },
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
