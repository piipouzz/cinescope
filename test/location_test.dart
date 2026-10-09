import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cinescope/models/cinema.dart';
import 'package:cinescope/services/location_service.dart';

class FakeGps extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  int requests = 0;
  int positions = 0;
  Object? error;
  Position position = Position(
    latitude: 43.5,
    longitude: 5.4,
    timestamp: DateTime.now(),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    requests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    positions++;
    expect(locationSettings!.accuracy, LocationAccuracy.high);
    expect(locationSettings.timeLimit, const Duration(seconds: 15));
    if (error != null) throw error!;
    return position;
  }
}

const simulatedCinema = Cinema(
  id: 'node/123',
  name: 'Cinéma test simulé',
  latitude: 43.5,
  longitude: 5.4,
);

Future<double> distance(FakeGps gps, Cinema cinema) async =>
    (await LocationService(platform: gps).checkDistance(cinema)).meters;

void main() {
  test('Distance nulle et distance connue avec seuil explicite', () async {
    expect(await distance(FakeGps(), simulatedCinema), 0);
    final far = const Cinema(
      id: 'node/2',
      name: 'Test',
      latitude: 43.51,
      longitude: 5.4,
    );
    expect(await distance(FakeGps(), far), closeTo(1112, 2));
    expect(CinemaDistance.proximityThreshold, 200);
    expect(formatCinemaDistance(150), '150 m');
    expect(formatCinemaDistance(1250), '1.25 km');
  });
  test('Permission demandée uniquement si nécessaire', () async {
    final gps = FakeGps()..permission = LocationPermission.denied;
    expect(await distance(gps, simulatedCinema), 0);
    expect(gps.requests, 1);
    expect(gps.positions, 1);
  });
  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
    LocationPermission.unableToDetermine,
  ]) {
    test('Permission $permission : aucune position ni confirmation', () async {
      final gps = FakeGps()
        ..permission = permission
        ..requested = permission;
      await expectLater(
        distance(gps, simulatedCinema),
        throwsA(isA<LocationException>()),
      );
      expect(gps.positions, 0);
      expect(gps.requests, permission == LocationPermission.denied ? 1 : 0);
    });
  }
  test('GPS désactivé', () async {
    final gps = FakeGps()..enabled = false;
    await expectLater(
      distance(gps, simulatedCinema),
      throwsA(isA<LocationException>()),
    );
    expect(gps.positions, 0);
  });
  for (final error in [
    TimeoutException('timeout'),
    const LocationServiceDisabledException(),
    PermissionDeniedException('denied'),
    StateError('failure'),
  ]) {
    test('Erreur native ${error.runtimeType}', () async {
      await expectLater(
        distance(FakeGps()..error = error, simulatedCinema),
        throwsA(isA<LocationException>()),
      );
    });
  }
}
