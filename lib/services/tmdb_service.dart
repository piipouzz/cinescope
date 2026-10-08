import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/app_config.dart';
import '../models/movie.dart';

class TmdbException implements Exception {
  const TmdbException(this.message);

  final String message;
}

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

    return _client.get(uri).timeout(const Duration(seconds: 15));
  }

  Future<List<Movie>> fetchPopularMovies() async {
    try {
      final response = await get(
        '/movie/popular',
        queryParameters: {'language': 'fr-FR'},
      );
      if (response.statusCode != 200) {
        throw TmdbException(
          response.statusCode == 401
              ? 'La clé API TMDB est invalide.'
              : 'TMDB est indisponible (HTTP ${response.statusCode}).',
        );
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic> || data['results'] is! List) {
        throw const FormatException();
      }
      return (data['results'] as List).map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException();
        return Movie.fromJson(item);
      }).toList();
    } on http.ClientException {
      throw const TmdbException('Connexion impossible. Vérifiez votre réseau.');
    } on TimeoutException {
      throw const TmdbException(
        'TMDB met trop de temps à répondre. Réessayez.',
      );
    } on FormatException {
      throw const TmdbException('La réponse de TMDB est illisible.');
    }
  }

  void dispose() {
    _client.close();
  }
}
