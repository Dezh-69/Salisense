import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/system_status.dart';

class StatusCard extends StatelessWidget {
  final SystemStatus status;

  const StatusCard({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SYSTEM STATUS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildStatusItem(
                  'FW Pump',
                  status.isFreshwaterPumpActive,
                  Icons.water_drop,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'SW Pump',
                  status.isSaltwaterPumpActive,
                  Icons.waves,
                ),
              ),
              Expanded(
                child: _buildStatusItem(
                  'Sensor',
                  status.isSensorHealthy,
                  Icons.sensors,
                  isReversed: true, // true means healthy is good
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isActive, IconData icon, {bool isReversed = false}) {
    // For pumps, active = accent. For sensor, healthy = online
    Color activeColor = isReversed ? AppColors.online : AppColors.accent;
    Color color = isActive ? activeColor : AppColors.textMuted;
    String statusText = isActive ? (isReversed ? 'OK' : 'ON') : (isReversed ? 'FAULT' : 'OFF');

    if (isReversed && !isActive) color = AppColors.alertSensorFault; // Sensor fault

    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
