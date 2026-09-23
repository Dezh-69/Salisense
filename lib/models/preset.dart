/// Model representing the active Tilapia grow-out preset
class Preset {
  final String name;
  final double minPpt;
  final double maxPpt;

  Preset({
    required this.name,
    required this.minPpt,
    required this.maxPpt,
  });

  factory Preset.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) {
      return Preset(name: 'Loading...', minPpt: 0.0, maxPpt: 0.0);
    }
    return Preset(
      name: json['name'] ?? 'Unknown Preset',
      minPpt: (json['min_ppt'] ?? 0.0).toDouble(),
      maxPpt: (json['max_ppt'] ?? 0.0).toDouble(),
    );
  }
}
