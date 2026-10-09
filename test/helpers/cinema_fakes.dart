import 'package:geolocator/geolocator.dart';

const cinemaJson = {
  'type': 'node',
  'id': 1,
  'lat': 43.5,
  'lon': 5.4,
  'tags': {
    'amenity': 'cinema',
    'name': 'Cinéma de test',
    'addr:street': 'Rue de test',
    'addr:housenumber': '12',
    'addr:city': 'Ville de test',
    'description': 'Description simulée pour les tests.',
  },
};

Position testPosition({double latitude = 43.5, double longitude = 5.4}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class FakeGps extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int positionRequests = 0;
  LocationSettings? settings;
  Future<Position> Function() locate = () async => testPosition();

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    positionRequests++;
    settings = locationSettings;
    return locate();
  }
}
