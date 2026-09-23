import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/salinity_reading.dart';
import '../models/preset.dart';

class SalinityGauge extends StatelessWidget {
  final SalinityReading? reading;
  final Preset? preset;

  const SalinityGauge({
    super.key,
    required this.reading,
    required this.preset,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen width to calculate a responsive gauge size
    final screenWidth = MediaQuery.of(context).size.width;
    // Use 60% of screen width, but cap it between 200 and 350 pixels
    final double gaugeSize = (screenWidth * 0.6).clamp(200.0, 350.0);

    // Determine color based on reading vs preset
    Color gaugeColor = AppColors.gaugeNormal;
    if (reading != null && preset != null && preset!.maxPpt > 0) {
      if (reading!.ppt < preset!.minPpt) {
        gaugeColor = AppColors.gaugeLow;
      } else if (reading!.ppt > preset!.maxPpt) {
        gaugeColor = AppColors.gaugeHigh;
      }
    }

    return Container(
      width: gaugeSize,
      height: gaugeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: gaugeColor.withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
        border: Border.all(
          color: gaugeColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated liquid fill / radial progress could go here
          // For now, a clean typographic display
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'LIVE SALINITY',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              if (reading == null)
                const CircularProgressIndicator(color: AppColors.accent)
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      reading!.ppt.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        fontSize: 64,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ppt',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
