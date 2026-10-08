import 'package:http/http.dart' as http;

import '../app/app_config.dart';

class TmdbService {
  TmdbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<http.Response> get(
    String endpoint, {
    Map<String, String> queryParameters = const {},
  }) async {
    if (AppConfig.tmdbApiKey.isEmpty) {
      throw StateError('La clé TMDB_API_KEY est manquante.');
    }

    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.https('api.themoviedb.org', '/3$path', {
      ...queryParameters,
      'api_key': AppConfig.tmdbApiKey,
    });

    return _client.get(uri);
  }

  void dispose() {
    _client.close();
  }
}
