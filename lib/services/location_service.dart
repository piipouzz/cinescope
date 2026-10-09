import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/cinema.dart';

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;
}

class CinemaDistance {
  const CinemaDistance({required this.meters, required this.accuracy});
  static const proximityThreshold = 200.0;
  final double meters;
  final double accuracy;
  bool get isNearby => meters <= proximityThreshold;
}

class LocationService {
  LocationService({GeolocatorPlatform? platform})
    : _platform = platform ?? GeolocatorPlatform.instance;
  final GeolocatorPlatform _platform;
  Future<CinemaDistance> checkDistance(Cinema cinema) async {
    try {
      if (!await _platform.isLocationServiceEnabled()) {
        throw const LocationException(
          'Le GPS est désactivé. Activez la localisation puis réessayez.',
        );
      }
      var permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(
          'Localisation refusée définitivement. Autorisez-la dans les réglages de l’application.',
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const LocationException('Autorisation de localisation refusée.');
      }
      final position = await _platform.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!position.latitude.isFinite ||
          !position.longitude.isFinite ||
          position.latitude.abs() > 90 ||
          position.longitude.abs() > 180 ||
          position.isMocked) {
        throw const LocationException(
          'La position obtenue ne permet pas de vérifier votre proximité.',
        );
      }
      return CinemaDistance(
        meters: Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          cinema.latitude,
          cinema.longitude,
        ),
        accuracy: position.accuracy,
      );
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException(
        'La position n’a pas pu être obtenue à temps. Réessayez.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        'Le GPS est désactivé. Activez la localisation puis réessayez.',
      );
    } on PermissionDeniedException {
      throw const LocationException('Autorisation de localisation refusée.');
    } catch (_) {
      throw const LocationException(
        'Impossible d’obtenir votre position. Réessayez.',
      );
    }
  }
}

String formatCinemaDistance(double meters) => meters < 1000
    ? '${meters.toStringAsFixed(0)} m'
    : '${(meters / 1000).toStringAsFixed(2)} km';
