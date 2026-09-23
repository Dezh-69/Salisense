import 'package:flutter/material.dart';
import '../config/theme.dart';

class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;

  const ConnectionIndicator({
    super.key,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected 
            ? AppColors.online.withValues(alpha: 0.1) 
            : AppColors.offline.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected 
              ? AppColors.online.withValues(alpha: 0.3) 
              : AppColors.offline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? AppColors.online : AppColors.offline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected ? 'ONLINE' : 'OFFLINE',
            style: TextStyle(
              color: isConnected ? AppColors.online : AppColors.offline,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
