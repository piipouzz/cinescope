import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:cinescope/providers/movie_provider.dart';
import 'package:cinescope/providers/theme_provider.dart';
import 'package:cinescope/services/tmdb_service.dart';

class StubTmdbService extends TmdbService {
  StubTmdbService(this.respond);

  final Future<http.Response> Function() respond;
  int calls = 0;

  @override
  Future<http.Response> get(
    String endpoint, {
    Map<String, String> queryParameters = const {},
  }) {
    calls++;
    return respond();
  }
}

ProviderContainer createContainer(TmdbService service) {
  final container = ProviderContainer(
    overrides: [tmdbServiceProvider.overrideWithValue(service)],
  );
  addTearDown(service.dispose);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('Chargement et récupération partagés sans requête répétée', () async {
    final response = Completer<http.Response>();
    final service = StubTmdbService(() => response.future);
    final container = createContainer(service);
    final loadingStates = <bool>[];
    container.listen(popularMoviesProvider, (previous, next) {
      loadingStates.add(next.isLoading);
    }, fireImmediately: true);

    final loading = container.read(popularMoviesProvider.future);
    expect(container.read(popularMoviesProvider).isLoading, isTrue);
    expect(container.read(popularMoviesProvider.future), same(loading));
    expect(service.calls, 1);

    response.complete(
      http.Response('{"results":[{"id":42,"title":"Le Voyage"}]}', 200),
    );
    final movies = await loading;
    expect(movies.single.title, 'Le Voyage');
    expect(container.read(popularMoviesProvider).isLoading, isFalse);
    expect(container.read(popularMoviesProvider).hasError, isFalse);
    expect(loadingStates, [true, false]);
    expect(() => movies.clear(), throwsUnsupportedError);
    await container.read(popularMoviesProvider.future);
    expect(service.calls, 1);
  });

  for (final status in [401, 500]) {
    test(
      'Une erreur HTTP $status est exposée puis une invalidation relance',
      () async {
        var attempts = 0;
        final service = StubTmdbService(
          () async => attempts++ == 0
              ? http.Response('{}', status)
              : http.Response('{"results":[{"id":1,"title":"Retour"}]}', 200),
        );
        final container = createContainer(service);

        await expectLater(
          container.read(popularMoviesProvider.future),
          throwsA(isA<TmdbException>()),
        );
        final state = container.read(popularMoviesProvider);
        expect(state.isLoading, isFalse);
        expect(
          (state.error as TmdbException).message,
          status == 401
              ? 'La clé API TMDB est invalide.'
              : 'TMDB est indisponible (HTTP 500).',
        );
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(service.calls, 1);

        container.invalidate(popularMoviesProvider);
        final retry = container.read(popularMoviesProvider.future);
        expect(container.read(popularMoviesProvider).isLoading, isTrue);
        expect((await retry).single.title, 'Retour');
        expect(container.read(popularMoviesProvider).hasError, isFalse);
        expect(service.calls, 2);
      },
    );
  }

  test('Une erreur réseau est conservée sans exposer la requête', () async {
    final service = StubTmdbService(
      () async => throw http.ClientException('offline'),
    );
    final container = createContainer(service);
    await expectLater(
      container.read(popularMoviesProvider.future),
      throwsA(isA<TmdbException>()),
    );
    final state = container.read(popularMoviesProvider);
    expect(state.isLoading, isFalse);
    expect(
      (state.error as TmdbException).message,
      'Connexion impossible. Vérifiez votre réseau.',
    );
  });

  test('Invalider actualise la liste et conserve le service injecté', () async {
    var id = 0;
    final service = StubTmdbService(
      () async => http.Response('{"results":[{"id":${++id}}]}', 200),
    );
    final container = createContainer(service);
    expect((await container.read(popularMoviesProvider.future)).single.id, 1);
    container.invalidate(popularMoviesProvider);
    expect((await container.read(popularMoviesProvider.future)).single.id, 2);
    expect(container.read(tmdbServiceProvider), same(service));
    expect(service.calls, 2);
  });

  test('Un catalogue vide est un succès', () async {
    final service = StubTmdbService(
      () async => http.Response('{"results":[]}', 200),
    );
    final container = createContainer(service);
    expect(await container.read(popularMoviesProvider.future), isEmpty);
    expect(container.read(popularMoviesProvider).isLoading, isFalse);
    expect(container.read(popularMoviesProvider).hasError, isFalse);
  });

  test(
    'Une réponse après fermeture du container ne notifie plus les widgets',
    () async {
      final response = Completer<http.Response>();
      final service = StubTmdbService(() => response.future);
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [tmdbServiceProvider.overrideWithValue(service)],
      );
      var notifications = 0;
      container.listen(
        popularMoviesProvider,
        (previous, next) => notifications++,
        fireImmediately: true,
      );
      container.dispose();
      response.complete(http.Response('{"results":[]}', 200));
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
    },
  );

  test('Le thème rose démarre en mode clair et reste modifiable', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(themeProvider), ThemeMode.light);
    container.read(themeProvider.notifier).setThemeMode(ThemeMode.system);
    expect(container.read(themeProvider), ThemeMode.system);
  });
}
