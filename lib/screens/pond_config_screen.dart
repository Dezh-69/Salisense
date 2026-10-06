import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../config/constants.dart';
import '../config/theme.dart';

/// Pond Configuration screen — allows farmers to input their pond dimensions
/// so the system can calculate an accurate pump fault timeout.
///
/// Formula: timeout_seconds = (pond_volume_L / pump_flow_rate_Lpm) × 60
///
/// The calculated timeout is written to Firebase at
///   devices/{deviceCode}/settings/pump_timeout
/// where the ESP32 picks it up via a real-time stream listener.
class PondConfigScreen extends StatefulWidget {
  final String deviceCode;

  const PondConfigScreen({
    super.key,
    required this.deviceCode,
  });

  @override
  State<PondConfigScreen> createState() => _PondConfigScreenState();
}

class _PondConfigScreenState extends State<PondConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _volumeController = TextEditingController();
  final _flowRateController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;
  int? _savedTimeoutSeconds;

  FirebaseDatabase get _db => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: 'https://salisense-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

  @override
  void initState() {
    super.initState();
    _loadExistingSettings();
  }

  /// Load previously saved pond settings from Firebase (if any).
  Future<void> _loadExistingSettings() async {
    try {
      final snapshot =
          await _db.ref(AppConstants.pathSettings(widget.deviceCode)).get();
      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        if (data['pond_volume'] != null) {
          _volumeController.text = data['pond_volume'].toString();
        }
        if (data['pump_flow_rate'] != null) {
          _flowRateController.text = data['pump_flow_rate'].toString();
        }
        if (data['pump_timeout'] != null) {
          _savedTimeoutSeconds = (data['pump_timeout'] as num).toInt();
        }
      }
    } catch (_) {
      // First-time use — no settings yet, which is fine.
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// Calculate the pump timeout in seconds from the current form values.
  /// Returns null if inputs are invalid.
  int? _calculateTimeoutSeconds() {
    final volume = double.tryParse(_volumeController.text);
    final flowRate = double.tryParse(_flowRateController.text);
    if (volume != null && flowRate != null && flowRate > 0 && volume > 0) {
      return ((volume / flowRate) * 60).round();
    }
    return null;
  }

  /// Format seconds into a human-readable duration string.
  String _formatDuration(int totalSeconds) {
    if (totalSeconds < 60) return '$totalSeconds seconds';
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    }
    return '$minutes min';
  }

  /// Validate, calculate, and write settings to Firebase.
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final volume = double.parse(_volumeController.text);
    final flowRate = double.parse(_flowRateController.text);
    final timeoutSeconds = ((volume / flowRate) * 60).round();

    setState(() => _isSaving = true);

    try {
      await _db.ref(AppConstants.pathSettings(widget.deviceCode)).set({
        'pond_volume': volume,
        'pump_flow_rate': flowRate,
        'pump_timeout': timeoutSeconds,
      });

      if (mounted) {
        setState(() => _savedTimeoutSeconds = timeoutSeconds);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settings saved! Pump timeout: ${_formatDuration(timeoutSeconds)}',
            ),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: AppColors.offline,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _flowRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pond Configuration'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Info banner ──
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.cardGradient,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.info_outline,
                                color: AppColors.accent, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Configure your pond so the system can calculate '
                              'accurate pump fault detection timeouts.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Section label ──
                    Text(
                      'POND PARAMETERS',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Pond Volume ──
                    _buildInputCard(
                      icon: Icons.water,
                      label: 'Pond Volume',
                      suffix: 'Liters',
                      controller: _volumeController,
                      hint: 'e.g. 1000',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final v = double.tryParse(value);
                        if (v == null || v <= 0) return 'Enter a valid volume';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // ── Pump Flow Rate ──
                    _buildInputCard(
                      icon: Icons.speed,
                      label: 'Pump Flow Rate',
                      suffix: 'L/min',
                      controller: _flowRateController,
                      hint: 'e.g. 5',
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final v = double.tryParse(value);
                        if (v == null || v <= 0) {
                          return 'Enter a valid flow rate';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    // ── Live timeout preview ──
                    Builder(
                      builder: (_) {
                        final timeout = _calculateTimeoutSeconds();
                        if (timeout == null) return const SizedBox.shrink();

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.2),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: AppColors.accent, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CALCULATED PUMP TIMEOUT',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textMuted,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDuration(timeout),
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Currently saved value indicator
                    if (_savedTimeoutSeconds != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Currently saved: ${_formatDuration(_savedTimeoutSeconds!)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 32),

                    // ── Save button ──
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              AppColors.accent.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'Save Configuration',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── How it works explanation ──
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.cardGradient,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceLight),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'HOW IT WORKS',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'The pump timeout determines how long the system '
                            'waits for a measurable salinity change before '
                            'flagging a pump fault.\n\n'
                            'Formula:  Timeout = (Volume ÷ Flow Rate) × 60\n\n'
                            'A larger pond needs more time for the pump to '
                            'produce a detectable change in salinity, '
                            'preventing false "pump failure" alarms.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  /// Reusable input card with icon, label, and styled TextFormField.
  Widget _buildInputCard({
    required IconData icon,
    required String label,
    required String suffix,
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
              suffixText: suffix,
              suffixStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.surfaceHighlight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.surfaceHighlight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.accent, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.offline),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
            onChanged: (_) => setState(() {}), // Triggers live timeout preview
          ),
        ],
      ),
    );
  }
}
