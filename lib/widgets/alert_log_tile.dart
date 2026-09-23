import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';
import '../models/alert.dart';

class AlertLogTile extends StatelessWidget {
  final Alert alert;

  const AlertLogTile({
    super.key,
    required this.alert,
  });

  IconData _getIcon() {
    switch (alert.type) {
      case AlertType.sensorFault:
        return Icons.sensors_off;
      case AlertType.pumpFault:
        return Icons.error_outline;
      case AlertType.lowReservoir:
        return Icons.water_drop_outlined;
      case AlertType.overcorrection:
        return Icons.trending_up;
    }
  }

  Color _getColor() {
    switch (alert.type) {
      case AlertType.sensorFault:
        return AppColors.alertSensorFault;
      case AlertType.pumpFault:
        return AppColors.alertPumpFault;
      case AlertType.lowReservoir:
        return AppColors.alertLowReservoir;
      case AlertType.overcorrection:
        return AppColors.alertOvercorrection;
    }
  }

  String _getLabel() {
    switch (alert.type) {
      case AlertType.sensorFault:
        return 'Sensor Fault';
      case AlertType.pumpFault:
        return 'Pump Fault';
      case AlertType.lowReservoir:
        return 'Low Reservoir';
      case AlertType.overcorrection:
        return 'Overcorrection';
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm:ss');
    final dateFormat = DateFormat('MMM dd, yyyy');
    final color = _getColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getIcon(), color: color, size: 20),
        ),
        title: Text(
          _getLabel(),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            alert.message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              timeFormat.format(alert.timestamp),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
            Text(
              dateFormat.format(alert.timestamp),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
