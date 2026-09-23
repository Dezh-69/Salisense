import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/preset.dart';

class PresetCard extends StatelessWidget {
  final Preset? preset;

  const PresetCard({
    super.key,
    required this.preset,
  });

  @override
  Widget build(BuildContext context) {
    if (preset == null) return const SizedBox.shrink();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACTIVE PRESET',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Icon(Icons.tune, color: AppColors.accent, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              preset!.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.accentLight,
              ),
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                _buildRangeIndicator('MIN', preset!.minPpt),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('—', style: TextStyle(color: AppColors.textMuted)),
                ),
                _buildRangeIndicator('MAX', preset!.maxPpt),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeIndicator(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Text(
              'ppt',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
