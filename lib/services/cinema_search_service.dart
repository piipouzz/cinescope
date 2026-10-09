import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/cinema_area.dart';

class CinemaSearchException implements Exception {
  const CinemaSearchException(this.message);
  final String message;
}

class CinemaSearchService {
  CinemaSearchService({http.Client? client, GeolocatorPlatform? gps})
    : _client = client ?? http.Client(),
      _gps = gps ?? GeolocatorPlatform.instance;

  final http.Client _client;
  final GeolocatorPlatform _gps;
  final _cache = <String, List<CinemaArea>>{};
  final _pending = <String, Future<List<CinemaArea>>>{};

  Future<List<CinemaArea>> searchCities(String name) {
    final normalized = name.trim().toLowerCase();
    if (normalized.length < 2 || normalized.length > 100) {
      return Future.error(
        const CinemaSearchException(
          'Saisissez le nom d’une ville (2 à 100 caractères).',
        ),
      );
    }
    if (_cache.containsKey(normalized)) return Future.value(_cache[normalized]);
    return _pending[normalized] ??= _search(normalized).whenComplete(() {
      _pending.remove(normalized);
    });
  }

  Future<List<CinemaArea>> _search(String name) async {
    try {
      final response = await _client
          .get(
            Uri.https('geo.api.gouv.fr', '/communes', {
              'nom': name,
              'fields': 'nom,code,centre,codeDepartement',
              'boost': 'population',
              'limit': '5',
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw const CinemaSearchException(
          'La recherche de villes est indisponible. Réessayez plus tard.',
        );
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) throw const FormatException();
      final cities = <CinemaArea>[];
      for (final city in data) {
        if (city is! Map || city['nom'] is! String || city['centre'] is! Map) {
          continue;
        }
        final coordinates = city['centre']['coordinates'];
        if (coordinates is! List ||
            coordinates.length != 2 ||
            coordinates[0] is! num ||
            coordinates[1] is! num) {
          continue;
        }
        final lat = (coordinates[1] as num).toDouble();
        final lon = (coordinates[0] as num).toDouble();
        if (!lat.isFinite ||
            !lon.isFinite ||
            lat.abs() > 90 ||
            lon.abs() > 180) {
          continue;
        }
        final department = city['codeDepartement'];
        cities.add(
          CinemaArea(
            label:
                '${city['nom']}${department is String ? ' ($department)' : ''}',
            latitude: lat,
            longitude: lon,
          ),
        );
      }
      return _cache[name] = List.unmodifiable(cities);
    } on TimeoutException {
      throw const CinemaSearchException(
        'La recherche de villes met trop de temps à répondre.',
      );
    } on http.ClientException {
      throw const CinemaSearchException(
        'Connexion impossible pour rechercher cette ville.',
      );
    } on FormatException {
      throw const CinemaSearchException(
        'Les coordonnées de la ville sont indisponibles.',
      );
    }
  }

  Future<CinemaArea> aroundMe() async {
    try {
      if (!await _gps.isLocationServiceEnabled()) {
        throw const CinemaSearchException(
          'Le GPS est désactivé. Activez la localisation puis réessayez.',
        );
      }
      var permission = await _gps.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _gps.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const CinemaSearchException(
          'Autorisez la localisation dans les réglages de l’application.',
        );
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw const CinemaSearchException(
          'Autorisation de localisation refusée.',
        );
      }
      final position = await _gps.getCurrentPosition(
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
        throw const CinemaSearchException(
          'Votre position n’a pas pu être déterminée.',
        );
      }
      return CinemaArea(
        label: 'Autour de moi',
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on CinemaSearchException {
      rethrow;
    } on TimeoutException {
      throw const CinemaSearchException(
        'La localisation met trop de temps à répondre. Réessayez.',
      );
    } catch (_) {
      throw const CinemaSearchException(
        'Impossible d’obtenir votre position. Vérifiez les autorisations et le GPS.',
      );
    }
  }

  void dispose() => _client.close();
}
