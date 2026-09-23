import 'package:flutter/material.dart';
import '../services/realtime_service.dart';
import '../services/export_service.dart';
import '../models/salinity_reading.dart';
import '../models/alert.dart';
import '../widgets/log_tile.dart';
import '../widgets/alert_log_tile.dart';
import '../config/theme.dart';

class LogScreen extends StatefulWidget {
  final String deviceCode;

  const LogScreen({super.key, required this.deviceCode});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  late final RealtimeService _realtime;
  List<SalinityReading> _currentLogs = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _realtime = RealtimeService(deviceCode: widget.deviceCode);
  }

  Future<void> _handleExport() async {
    if (_currentLogs.isEmpty) return;
    
    setState(() => _isExporting = true);
    await ExportService.exportLogsToCsv(_currentLogs);
    if (mounted) {
      setState(() => _isExporting = false);
    }
  }

  Widget _buildSalinityTab() {
    return StreamBuilder<List<SalinityReading>>(
      stream: _realtime.streamSalinityLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        final logs = snapshot.data ?? [];
        
        // Update local state for export capability
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _currentLogs.length != logs.length) {
            setState(() => _currentLogs = logs);
          }
        });

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_toggle_off, size: 64, color: AppColors.surfaceHighlight),
                const SizedBox(height: 16),
                Text(
                  'No salinity logs yet',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            return LogTile(reading: logs[index]);
          },
        );
      },
    );
  }

  Widget _buildAlertsTab() {
    return StreamBuilder<List<Alert>>(
      stream: _realtime.streamAlertLogs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          );
        }

        final alerts = snapshot.data ?? [];

        if (alerts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppColors.online),
                const SizedBox(height: 16),
                Text(
                  'No fault alerts recorded',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Alerts will appear here when faults are detected.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            return AlertLogTile(alert: alerts[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logs'),
          actions: [
            IconButton(
              icon: _isExporting 
                  ? const SizedBox(
                      width: 20, 
                      height: 20, 
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        color: AppColors.accent,
                      ),
                    )
                  : const Icon(Icons.file_download),
              onPressed: _isExporting || _currentLogs.isEmpty ? null : _handleExport,
              tooltip: 'Export Salinity Logs to CSV',
            ),
          ],
          bottom: TabBar(
            indicatorColor: AppColors.accent,
            labelColor: AppColors.accent,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.water_drop), text: 'Salinity'),
              Tab(icon: Icon(Icons.warning_amber), text: 'Alerts'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSalinityTab(),
            _buildAlertsTab(),
          ],
        ),
      ),
    );
  }
}
