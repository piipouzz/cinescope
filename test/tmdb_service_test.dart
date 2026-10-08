import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cinescope/services/tmdb_service.dart';

class ResponseTmdbService extends TmdbService {
  ResponseTmdbService(this.respond);

  final Future<http.Response> Function() respond;

  @override
  Future<http.Response> get(
    String endpoint, {
    Map<String, String> queryParameters = const {},
  }) {
    expect(endpoint, '/movie/popular');
    expect(queryParameters['language'], 'fr-FR');
    return respond();
  }
}

void main() {
  const apiKey = String.fromEnvironment('TMDB_API_KEY');

  test('Les films populaires sont décodés en français', () async {
    final service = ResponseTmdbService(
      () async => http.Response(
        jsonEncode({
          'results': [
            {'id': 1, 'title': 'Été', 'vote_average': 7.5},
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    addTearDown(service.dispose);
    final movies = await service.fetchPopularMovies();
    expect(movies.single.title, 'Été');
    expect(movies.single.voteAverage, 7.5);
  });

  test('Un résultat vide reste une liste vide', () async {
    final service = ResponseTmdbService(
      () async => http.Response('{"results":[]}', 200),
    );
    addTearDown(service.dispose);
    expect(await service.fetchPopularMovies(), isEmpty);
  });

  for (final status in [401, 500]) {
    test('Une erreur HTTP $status est signalée', () async {
      final service = ResponseTmdbService(
        () async => http.Response('{}', status),
      );
      addTearDown(service.dispose);
      await expectLater(
        service.fetchPopularMovies(),
        throwsA(isA<TmdbException>()),
      );
    });
  }

  for (final body in ['invalid', '{}', '{"results":[null]}']) {
    test('Une réponse mal formée ($body) est signalée', () async {
      final service = ResponseTmdbService(() async => http.Response(body, 200));
      addTearDown(service.dispose);
      await expectLater(
        service.fetchPopularMovies(),
        throwsA(isA<TmdbException>()),
      );
    });
  }

  for (final error in [
    http.ClientException('offline'),
    TimeoutException('timeout'),
  ]) {
    test('Une erreur réseau ${error.runtimeType} est signalée', () async {
      final service = ResponseTmdbService(() async => throw error);
      addTearDown(service.dispose);
      await expectLater(
        service.fetchPopularMovies(),
        throwsA(isA<TmdbException>()),
      );
    });
  }

  test('Le service utilise la clé v3 ou refuse une clé absente', () async {
    var requestCount = 0;
    final service = TmdbService(
      client: MockClient((request) async {
        requestCount++;
        expect(request.url.scheme, 'https');
        expect(request.url.host, 'api.themoviedb.org');
        expect(request.url.path, '/3/movie/popular');
        expect(request.url.queryParameters['api_key'], apiKey);
        expect(request.url.queryParameters['language'], 'fr-FR');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response('{}', 200);
      }),
    );
    addTearDown(service.dispose);

    final response = service.get(
      'movie/popular',
      queryParameters: {'language': 'fr-FR', 'api_key': 'ignored'},
    );

    if (apiKey.isEmpty) {
      await expectLater(response, throwsStateError);
      expect(requestCount, 0);
    } else {
      expect((await response).statusCode, 200);
      expect(requestCount, 1);
    }
  });
}
