import 'dart:convert';

/// Model representing a registered ESP32 device
class Device {
  final String code;
  String name;

  Device({
    required this.code,
    required this.name,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      code: json['code'] ?? '',
      name: json['name'] ?? 'Unnamed Device',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
    };
  }

  /// Serialize a list of devices to a JSON string for SharedPreferences
  static String encodeList(List<Device> devices) {
    return jsonEncode(devices.map((d) => d.toJson()).toList());
  }

  /// Deserialize a JSON string from SharedPreferences to a list of devices
  static List<Device> decodeList(String jsonString) {
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((item) => Device.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }
}
