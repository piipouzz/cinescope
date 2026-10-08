import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/movie.dart';
import '../services/tmdb_service.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final service = TmdbService();
  ref.onDispose(service.dispose);
  return service;
});

final popularMoviesProvider = FutureProvider<List<Movie>>((ref) async {
  final service = ref.watch(tmdbServiceProvider);
  return List<Movie>.unmodifiable(await service.fetchPopularMovies());
}, retry: (retryCount, error) => null);
