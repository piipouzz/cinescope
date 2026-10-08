import 'package:flutter_test/flutter_test.dart';
import 'package:cinescope/models/movie.dart';

void main() {
  test('Movie.fromJson convertit les données TMDB', () {
    final movie = Movie.fromJson({
      'id': 42,
      'title': 'Le Voyage',
      'overview': 'Un voyage inattendu.',
      'poster_path': '/poster.jpg',
      'release_date': '2026-10-09',
      'vote_average': 8,
    });
    expect(movie.id, 42);
    expect(movie.title, 'Le Voyage');
    expect(movie.overview, 'Un voyage inattendu.');
    expect(movie.posterPath, '/poster.jpg');
    expect(movie.releaseDate, DateTime(2026, 10, 9));
    expect(movie.voteAverage, 8.0);
  });

  test('Movie.fromJson accepte les champs manquants ou nulls', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {
        'id': null,
        'title': null,
        'overview': null,
        'poster_path': null,
        'release_date': null,
        'vote_average': null,
      },
    ]) {
      final movie = Movie.fromJson(json);
      expect(movie.id, 0);
      expect(movie.title, 'Titre indisponible');
      expect(movie.overview, '');
      expect(movie.posterPath, isNull);
      expect(movie.releaseDate, isNull);
      expect(movie.voteAverage, 0.0);
    }
  });

  test('Les affiches vides et dates illisibles sont absentes', () {
    for (final date in ['', 'date-invalide']) {
      final movie = Movie.fromJson({
        'poster_path': ' ',
        'release_date': date,
        'vote_average': 7.6,
      });
      expect(movie.posterPath, isNull);
      expect(movie.releaseDate, isNull);
      expect(movie.voteAverage, 7.6);
    }
  });
}
