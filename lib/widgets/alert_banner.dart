import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/alert.dart';

class AlertBanner extends StatelessWidget {
  final Alert alert;

  const AlertBanner({
    super.key,
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    if (!alert.isActive) return const SizedBox.shrink();

    Color alertColor;
    IconData icon;
    String title;

    switch (alert.type) {
      case AlertType.sensorFault:
        alertColor = AppColors.alertSensorFault;
        icon = Icons.warning_amber_rounded;
        title = 'SENSOR FAULT';
        break;
      case AlertType.pumpFault:
        alertColor = AppColors.alertPumpFault;
        icon = Icons.error_outline;
        title = 'PUMP FAULT';
        break;
      case AlertType.lowReservoir:
        alertColor = AppColors.alertLowReservoir;
        icon = Icons.water_damage_outlined;
        title = 'LOW RESERVOIR';
        break;
      case AlertType.overcorrection:
        alertColor = AppColors.alertOvercorrection;
        icon = Icons.swap_vert;
        title = 'OVERCORRECTION';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alertColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: alertColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: alertColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
