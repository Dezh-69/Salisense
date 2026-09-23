// SaliSense Configuration Constants
// Defines Firebase paths and application-wide settings

class AppConstants {
  // --- Firebase RTDB Paths ---
  // The exact paths will be confirmed by the team (Open Question #1)
  // These are reasonable defaults based on the PRD
  
  static String pathCurrentSalinity(String deviceCode) => 'devices/$deviceCode/sensor/current_ppt';
  static String pathSalinityLogs(String deviceCode) => 'devices/$deviceCode/logs/salinity';
  static String pathActivePreset(String deviceCode) => 'devices/$deviceCode/system/active_preset';
  static String pathSystemStatus(String deviceCode) => 'devices/$deviceCode/system/status';
  static String pathAlerts(String deviceCode) => 'devices/$deviceCode/alerts/active';
  static String pathAlertLogs(String deviceCode) => 'devices/$deviceCode/logs/alerts';

  // --- Limits & Timings ---
  // Display only the last N logs to prevent excessive memory usage
  static const int maxLogsToDisplay = 1000;
  
  // Timeout for pump activation fault check
  static const int pumpFaultTimeoutSeconds = 24;
}
