/// Model representing a single salinity reading
class SalinityReading {
  final double ppt;
  final DateTime timestamp;

  SalinityReading({
    required this.ppt,
    required this.timestamp,
  });

  factory SalinityReading.fromJson(Map<dynamic, dynamic> json, String key) {
    return SalinityReading(
      ppt: (json['ppt'] ?? 0.0).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] ?? int.tryParse(key) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ppt': ppt,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}
