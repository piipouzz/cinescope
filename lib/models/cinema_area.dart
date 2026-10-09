import 'dart:math' as math;

class CinemaArea {
  const CinemaArea({
    required this.label,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 10000,
  });

  static const initial = CinemaArea(
    label: 'Aix-en-Provence (13)',
    latitude: 43.536,
    longitude: 5.3879,
  );

  final String label;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  String get key =>
      '${latitude.toStringAsFixed(6)}:${longitude.toStringAsFixed(6)}:$radiusMeters';
  String get radiusLabel => '${radiusMeters ~/ 1000} km';

  bool contains(double lat, double lon) {
    final radians = math.pi / 180;
    final a =
        math.pow(math.sin((lat - latitude) * radians / 2), 2) +
        math.cos(latitude * radians) *
            math.cos(lat * radians) *
            math.pow(math.sin((lon - longitude) * radians / 2), 2);
    final distance =
        6371000 *
        2 *
        math.atan2(math.sqrt(a.clamp(0, 1)), math.sqrt((1 - a).clamp(0, 1)));
    return distance <= radiusMeters;
  }

  @override
  bool operator ==(Object other) =>
      other is CinemaArea && key == other.key && label == other.label;
  @override
  int get hashCode => Object.hash(key, label);
}
