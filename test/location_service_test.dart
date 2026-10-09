import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cinescope/models/cinema.dart';
import 'package:cinescope/services/location_service.dart';

import 'helpers/cinema_fakes.dart';

void main() {
  final cinema = Cinema.fromJson(cinemaJson);
  test('Position réelle du plugin requise pour calculer la distance', () async {
    final gps = FakeGps();
    final result = await LocationService(platform: gps).checkDistance(cinema);
    expect(result.meters, closeTo(0, 0.01));
    expect(result.isNearby, isTrue);
    expect(result.accuracy, 10);
    expect(gps.positionRequests, 1);
    expect(gps.settings!.accuracy, LocationAccuracy.high);
    expect(gps.settings!.timeLimit, const Duration(seconds: 15));
  });
  test(
    'Distance calculée à vol d’oiseau et seuil explicite de 200 m',
    () async {
      final gps = FakeGps()..locate = () async => testPosition(latitude: 43.51);
      final result = await LocationService(platform: gps).checkDistance(cinema);
      expect(result.meters, closeTo(1112, 5));
      expect(result.isNearby, isFalse);
      expect(const CinemaDistance(meters: 200, accuracy: 10).isNearby, isTrue);
      expect(
        const CinemaDistance(meters: 200.1, accuracy: 10).isNearby,
        isFalse,
      );
    },
  );
  test('Permission demandée une seule fois puis localisation', () async {
    final gps = FakeGps()..permission = LocationPermission.denied;
    await LocationService(platform: gps).checkDistance(cinema);
    expect(gps.permissionRequests, 1);
    expect(gps.positionRequests, 1);
  });
  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test(
      'Permission $permission : aucune position ni présence confirmée',
      () async {
        final gps = FakeGps()
          ..permission = permission
          ..requestedPermission = permission;
        await expectLater(
          LocationService(platform: gps).checkDistance(cinema),
          throwsA(isA<LocationException>()),
        );
        expect(gps.positionRequests, 0);
        expect(
          gps.permissionRequests,
          permission == LocationPermission.denied ? 1 : 0,
        );
      },
    );
  }
  test('GPS désactivé : aucune requête de position', () async {
    final gps = FakeGps()..enabled = false;
    await expectLater(
      LocationService(platform: gps).checkDistance(cinema),
      throwsA(isA<LocationException>()),
    );
    expect(gps.positionRequests, 0);
  });
  for (final error in [
    TimeoutException('slow'),
    const LocationServiceDisabledException(),
    PermissionDeniedException('denied'),
    PlatformException(code: 'failed'),
  ]) {
    test('Erreur native contrôlée : ${error.runtimeType}', () async {
      final gps = FakeGps()..locate = () async => throw error;
      await expectLater(
        LocationService(platform: gps).checkDistance(cinema),
        throwsA(isA<LocationException>()),
      );
    });
  }
  test('Une position invalide est refusée', () async {
    final gps = FakeGps()
      ..locate = () async => testPosition(latitude: double.nan);
    await expectLater(
      LocationService(platform: gps).checkDistance(cinema),
      throwsA(isA<LocationException>()),
    );
  });
}
