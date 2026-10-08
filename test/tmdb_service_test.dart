import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:cinescope/services/tmdb_service.dart';

void main() {
  const apiKey = String.fromEnvironment('TMDB_API_KEY');

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
