/// Model representing the current system status
class SystemStatus {
  final bool isFreshwaterPumpActive;
  final bool isSaltwaterPumpActive;
  final bool isSensorHealthy;
  final bool isReservoirLow;

  SystemStatus({
    this.isFreshwaterPumpActive = false,
    this.isSaltwaterPumpActive = false,
    this.isSensorHealthy = true,
    this.isReservoirLow = false,
  });

  factory SystemStatus.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return SystemStatus();
    return SystemStatus(
      isFreshwaterPumpActive: json['freshwater_pump'] == true,
      isSaltwaterPumpActive: json['saltwater_pump'] == true,
      isSensorHealthy: json['sensor_status'] != 'fault', // Adjust based on actual data
      isReservoirLow: json['reservoir_low'] == true,
    );
  }
}
