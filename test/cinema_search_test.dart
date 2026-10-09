import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cinescope/models/cinema_area.dart';
import 'package:cinescope/services/cinema_search_service.dart';
import 'package:cinescope/services/cinema_service.dart';

import 'helpers/cinema_fakes.dart';

const paris = CinemaArea(
  label: 'Paris (75)',
  latitude: 48.8589,
  longitude: 2.347,
);
const lyon = CinemaArea(
  label: 'Ville simulée',
  latitude: 45.75,
  longitude: 4.85,
);

void main() {
  test(
    'Communes françaises : coordonnées, département, cache et requête partagée',
    () async {
      var calls = 0;
      final gps = FakeGps();
      final service = CinemaSearchService(
        gps: gps,
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'geo.api.gouv.fr');
          expect(request.url.queryParameters['nom'], 'paris');
          expect(request.url.queryParameters['limit'], '5');
          return http.Response(
            jsonEncode([
              {
                'nom': 'Paris',
                'codeDepartement': '75',
                'centre': {
                  'coordinates': [2.347, 48.8589],
                },
              },
              {
                'nom': 'Parisot',
                'codeDepartement': '81',
                'centre': {
                  'coordinates': [1.8, 43.7],
                },
              },
              {'nom': 'Sans coordonnées'},
              {
                'nom': 'Invalide',
                'centre': {
                  'coordinates': [1, 100],
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.dispose);
      final results = await Future.wait([
        service.searchCities('Paris'),
        service.searchCities(' PARIS '),
      ]);
      expect(results.first.length, 2);
      expect(results.first.first.label, 'Paris (75)');
      expect(results.first.first.latitude, 48.8589);
      expect(results.first.first.longitude, 2.347);
      expect(results.first, same(results.last));
      expect(await service.searchCities('paris'), same(results.first));
      expect(calls, 1);
      expect(gps.positionRequests, 0);
      expect(gps.permissionRequests, 0);
    },
  );

  for (final error in [500, 429, 'invalid', 'timeout', 'network']) {
    test(
      'Recherche de ville : erreur $error sans tentative automatique',
      () async {
        var calls = 0;
        final service = CinemaSearchService(
          client: MockClient((request) async {
            calls++;
            if (error == 'timeout') throw TimeoutException('simulated');
            if (error == 'network') throw http.ClientException('simulated');
            return http.Response(
              error == 'invalid' ? '{}' : '',
              error is int ? error : 200,
            );
          }),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.searchCities('Paris'),
          throwsA(isA<CinemaSearchException>()),
        );
        expect(calls, 1);
      },
    );
  }

  test('Ville inconnue et saisie trop courte', () async {
    var calls = 0;
    final service = CinemaSearchService(
      client: MockClient((request) async {
        calls++;
        return http.Response('[]', 200);
      }),
    );
    addTearDown(service.dispose);
    await expectLater(
      service.searchCities('a'),
      throwsA(isA<CinemaSearchException>()),
    );
    expect(calls, 0);
    expect(await service.searchCities('Ville inconnue'), isEmpty);
  });

  test(
    'Autour de moi utilise une position ponctuelle et ses coordonnées',
    () async {
      final gps = FakeGps()..permission = LocationPermission.denied;
      final service = CinemaSearchService(gps: gps);
      addTearDown(service.dispose);
      expect(gps.positionRequests, 0);
      final area = await service.aroundMe();
      expect(area.label, 'Autour de moi');
      expect(area.latitude, 43.5);
      expect(area.longitude, 5.4);
      expect(area.radiusMeters, 10000);
      expect(gps.settings!.timeLimit, const Duration(seconds: 15));
      expect(gps.permissionRequests, 1);
      expect(gps.positionRequests, 1);
    },
  );

  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
    LocationPermission.unableToDetermine,
  ]) {
    test(
      'Autour de moi : permission $permission refusée sans position',
      () async {
        final gps = FakeGps()
          ..permission = permission
          ..requestedPermission = permission;
        final service = CinemaSearchService(gps: gps);
        addTearDown(service.dispose);
        await expectLater(
          service.aroundMe(),
          throwsA(isA<CinemaSearchException>()),
        );
        expect(gps.positionRequests, 0);
      },
    );
  }
  test('Autour de moi : GPS désactivé, timeout et position invalide', () async {
    for (final gps in [
      FakeGps()..enabled = false,
      FakeGps()..locate = () async => throw TimeoutException('simulated'),
      FakeGps()..locate = () async => testPosition(latitude: double.nan),
    ]) {
      final service = CinemaSearchService(gps: gps);
      addTearDown(service.dispose);
      await expectLater(
        service.aroundMe(),
        throwsA(isA<CinemaSearchException>()),
      );
    }
  });

  test('Cache et requêtes distincts par coordonnées et rayon', () async {
    var now = DateTime.utc(2026);
    var calls = 0;
    final service = CinemaService(
      now: () => now,
      client: MockClient((request) async {
        calls++;
        final query = request.bodyFields['data']!;
        expect(query, contains('around:10000'));
        final area = query.contains('48.8589') ? paris : lyon;
        return http.Response(
          jsonEncode({
            'elements': [
              {
                ...cinemaJson,
                'id': calls,
                'lat': area.latitude,
                'lon': area.longitude,
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    final first = await Future.wait([
      service.fetchCinemas(area: paris),
      service.fetchCinemas(area: paris),
    ]);
    expect(first.first, same(first.last));
    now = now.add(const Duration(seconds: 31));
    final second = await service.fetchCinemas(area: lyon);
    expect(first.first.single.id, 'node/1');
    expect(second.single.id, 'node/2');
    expect(await service.fetchCinemas(area: paris), same(first.first));
    expect(calls, 2);
    expect(
      paris.key,
      isNot(
        CinemaArea(
          label: 'Paris',
          latitude: paris.latitude,
          longitude: paris.longitude,
          radiusMeters: 5000,
        ).key,
      ),
    );
  });

  test(
    'Secours limité au rayon réel : aucun résultat aixois pour Paris',
    () async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final service = CinemaService(
        now: () => now,
        client: MockClient((request) async {
          calls++;
          return http.Response('', 500);
        }),
        loadLocalCopy: () async => jsonEncode({
          'elements': [cinemaJson],
        }),
      );
      addTearDown(service.dispose);
      final aix = await service.fetchCinemas();
      expect(aix.single.id, 'node/1');
      now = now.add(const Duration(seconds: 31));
      await expectLater(
        service.fetchCinemas(area: paris),
        throwsA(isA<CinemaException>()),
      );
      expect(service.usingLocalCopyFor(paris), isFalse);
      expect(await service.fetchCinemas(), same(aix));
      expect(calls, 2);
    },
  );

  test('Deux zones simultanées respectent une seule requête réseau', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final service = CinemaService(
      client: MockClient((request) {
        calls++;
        return response.future;
      }),
    );
    addTearDown(service.dispose);
    final first = service.fetchCinemas(area: paris);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      service.fetchCinemas(area: lyon),
      throwsA(isA<CinemaException>()),
    );
    expect(calls, 1);
    response.complete(http.Response('{"elements":[]}', 200));
    await first;
  });
}
