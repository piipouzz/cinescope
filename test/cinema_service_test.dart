import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cinescope/providers/cinema_provider.dart';
import 'package:cinescope/services/cinema_service.dart';

import 'helpers/cinema_fakes.dart';

void main() {
  test(
    'Le cache local reste immédiatement accessible pendant la relance réseau',
    () async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final response = Completer<http.Response>();
      final service = CinemaService(
        now: () => now,
        client: MockClient(
          (request) async =>
              ++calls == 1 ? http.Response('', 500) : response.future,
        ),
        loadLocalCopy: () async => jsonEncode({
          'elements': [cinemaJson],
        }),
      );
      addTearDown(service.dispose);
      final cached = await service.fetchCinemas();
      now = now.add(const Duration(seconds: 31));
      service.requestNetworkRetry();
      final retry = service.fetchCinemas();
      expect(await service.fetchCinemas(), same(cached));
      response.complete(http.Response('{"elements":[]}', 200));
      expect(await retry, isEmpty);
      expect(service.usingLocalCopy, isFalse);
      expect(calls, 2);
    },
  );
  for (final failure in [500, 429, 'timeout', 'network', 'invalid']) {
    test(
      'Copie locale et cache sans nouvelle requête après $failure',
      () async {
        var calls = 0;
        var loads = 0;
        final service = CinemaService(
          client: MockClient((request) async {
            calls++;
            if (failure == 'timeout') throw TimeoutException('slow');
            if (failure == 'network') throw http.ClientException('offline');
            return http.Response(
              failure == 'invalid' ? '{}' : '',
              failure is int ? failure : 200,
            );
          }),
          loadLocalCopy: () async {
            loads++;
            return jsonEncode({
              'elements': [cinemaJson],
              'snapshot': {'exported_on': '2026-10-09'},
            });
          },
        );
        addTearDown(service.dispose);
        final result = await service.fetchCinemas();
        expect(result.single.id, 'node/1');
        expect(service.usingLocalCopy, isTrue);
        expect(service.localCopyDate, '2026-10-09');
        expect(await service.fetchCinemas(), same(result));
        service.requestNetworkRetry();
        expect(await service.fetchCinemas(), same(result));
        expect(calls, 1);
        expect(loads, 1);
      },
    );
  }
  test('Retry-After respecté puis retour manuel aux données réseau', () async {
    var now = DateTime.utc(2026, 10, 9);
    var calls = 0;
    final service = CinemaService(
      now: () => now,
      client: MockClient(
        (request) async => ++calls == 1
            ? http.Response('', 429, headers: {'retry-after': '120'})
            : http.Response(
                jsonEncode({
                  'elements': [
                    {...cinemaJson, 'id': 2},
                  ],
                }),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
      ),
      loadLocalCopy: () async => jsonEncode({
        'elements': [cinemaJson],
      }),
    );
    addTearDown(service.dispose);
    await service.fetchCinemas();
    now = now.add(const Duration(seconds: 31));
    service.requestNetworkRetry();
    expect((await service.fetchCinemas()).single.id, 'node/1');
    expect(calls, 1);
    now = now.add(const Duration(seconds: 90));
    expect((await service.fetchCinemas()).single.id, 'node/1');
    expect(calls, 1);
    service.requestNetworkRetry();
    expect((await service.fetchCinemas()).single.id, 'node/2');
    expect(service.usingLocalCopy, isFalse);
    await service.fetchCinemas();
    expect(calls, 2);
  });
  test('Une relance en échec conserve la copie locale', () async {
    var now = DateTime.utc(2026);
    final service = CinemaService(
      now: () => now,
      client: MockClient((request) async => http.Response('', 500)),
      loadLocalCopy: () async => jsonEncode({
        'elements': [cinemaJson],
      }),
    );
    addTearDown(service.dispose);
    final cached = await service.fetchCinemas();
    now = now.add(const Duration(seconds: 31));
    service.requestNetworkRetry();
    expect(await service.fetchCinemas(), same(cached));
    expect(service.usingLocalCopy, isTrue);
    expect(service.retryDelay.inSeconds, 30);
  });
  test('Copie locale illisible : erreur explicite', () async {
    final service = CinemaService(
      client: MockClient((request) async => http.Response('', 500)),
      loadLocalCopy: () async => 'invalid',
    );
    addTearDown(service.dispose);
    await expectLater(service.fetchCinemas(), throwsA(isA<CinemaException>()));
    expect(service.usingLocalCopy, isFalse);
  });
  test('Requête bornée, parsing et cache partagé pendant la session', () async {
    var calls = 0;
    final service = CinemaService(
      client: MockClient((request) async {
        calls++;
        expect(request.method, 'POST');
        expect(request.url.host, 'overpass-api.de');
        expect(request.bodyFields['data'], contains('[maxsize:67108864]'));
        expect(request.bodyFields['data'], CinemaService.query);
        return http.Response(
          jsonEncode({
            'elements': [cinemaJson, cinemaJson],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(service.dispose);
    final results = await Future.wait([
      service.fetchCinemas(),
      service.fetchCinemas(),
    ]);
    expect(results.first.single.id, 'node/1');
    expect(results.last, same(results.first));
    expect(await service.fetchCinemas(), same(results.first));
    expect(calls, 1);
    expect(() => results.first.clear(), throwsUnsupportedError);
  });
  test('FutureProvider expose le chargement et conserve le cache après invalidation', () async {
    final response = Completer<http.Response>();
    var calls = 0;
    final service = CinemaService(
      client: MockClient((request) {
        calls++;
        return response.future;
      }),
    );
    addTearDown(service.dispose);
    final container = ProviderContainer(
      overrides: [cinemaServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    final future = container.read(cinemasProvider.future);
    expect(container.read(cinemasProvider).isLoading, isTrue);
    response.complete(
      http.Response(
        jsonEncode({
          'elements': [cinemaJson],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    expect((await future).single.name, 'Cinéma de test');
    container.invalidate(cinemasProvider);
    expect((await container.read(cinemasProvider.future)).length, 1);
    expect(calls, 1);
  });
  test('Une erreur HTTP peut être relancée manuellement', () async {
    var calls = 0;
    var now = DateTime.utc(2026);
    final service = CinemaService(
      now: () => now,
      client: MockClient(
        (request) async => calls++ == 0
            ? http.Response('', 500)
            : http.Response('{"elements":[]}', 200),
      ),
    );
    addTearDown(service.dispose);
    final container = ProviderContainer(
      overrides: [cinemaServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(cinemasProvider.future),
      throwsA(isA<CinemaException>()),
    );
    expect(container.read(cinemasProvider).hasError, isTrue);
    now = now.add(const Duration(seconds: 31));
    container.invalidate(cinemasProvider);
    expect(await container.read(cinemasProvider.future), isEmpty);
    expect(calls, 2);
  });
  test('HTTP 429 respecte un délai avant une nouvelle requête', () async {
    var now = DateTime(2026, 10, 9);
    var calls = 0;
    final service = CinemaService(
      now: () => now,
      client: MockClient((request) async {
        calls++;
        return http.Response('', 429, headers: {'retry-after': '120'});
      }),
    );
    addTearDown(service.dispose);
    await expectLater(service.fetchCinemas(), throwsA(isA<CinemaException>()));
    await expectLater(service.fetchCinemas(), throwsA(isA<CinemaException>()));
    expect(calls, 1);
    now = now.add(const Duration(seconds: 121));
    await expectLater(service.fetchCinemas(), throwsA(isA<CinemaException>()));
    expect(calls, 2);
  });
  for (final body in [
    'invalid',
    '{}',
    '{"elements":[1]}',
    '{"elements":[],"remark":"timeout"}',
  ]) {
    test('Réponse mal formée ou partielle refusée : $body', () async {
      final service = CinemaService(
        client: MockClient((request) async => http.Response(body, 200)),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.fetchCinemas(),
        throwsA(isA<CinemaException>()),
      );
    });
  }
  for (final error in [
    http.ClientException('network'),
    TimeoutException('slow'),
  ]) {
    test('Erreur réseau contrôlée : ${error.runtimeType}', () async {
      final service = CinemaService(
        client: MockClient((request) async => throw error),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.fetchCinemas(),
        throwsA(isA<CinemaException>()),
      );
    });
  }
}
