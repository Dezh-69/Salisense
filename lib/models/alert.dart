/// Model representing an active alert
enum AlertType {
  sensorFault,
  pumpFault,
  lowReservoir,
  overcorrection,
}

class Alert {
  final AlertType type;
  final String message;
  final DateTime timestamp;
  final bool isActive;

  Alert({
    required this.type,
    required this.message,
    required this.timestamp,
    this.isActive = true,
  });

  factory Alert.fromJson(Map<dynamic, dynamic> json, String key) {
    AlertType type = AlertType.sensorFault;
    String typeStr = json['type'] ?? '';
    
    switch (typeStr) {
      case 'pump_fault':
        type = AlertType.pumpFault;
        break;
      case 'low_reservoir':
        type = AlertType.lowReservoir;
        break;
      case 'overcorrection':
        type = AlertType.overcorrection;
        break;
      default:
        type = AlertType.sensorFault;
    }

    return Alert(
      type: type,
      message: json['message'] ?? 'Unknown alert',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] ?? int.tryParse(key) ?? DateTime.now().millisecondsSinceEpoch,
      ),
      isActive: json['is_active'] ?? true,
    );
  }
}
