import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:cinescope/app/cinescope_app.dart';
import 'package:cinescope/models/movie.dart';
import 'package:cinescope/providers/movie_provider.dart';
import 'package:cinescope/providers/theme_provider.dart';
import 'package:cinescope/services/tmdb_service.dart';
import 'package:cinescope/widgets/movie_card.dart';

class FakeTmdbService extends TmdbService {
  FakeTmdbService(this.load);

  final Future<List<Movie>> Function() load;
  int calls = 0;

  @override
  Future<List<Movie>> fetchPopularMovies() {
    calls++;
    return load();
  }
}

final movie = Movie.fromJson({
  'id': 42,
  'title': 'Le Voyage',
  'vote_average': 8.2,
  'release_date': '2026-10-09',
});

Widget createApp(TmdbService service) {
  return ProviderScope(
    overrides: [tmdbServiceProvider.overrideWithValue(service)],
    child: const CinescopeApp(),
  );
}

void main() {
  testWidgets(
    'Une affiche en erreur et une date absente sont prises en charge',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = FakeTmdbService(
        () async => [
          Movie.fromJson({
            'id': 10,
            'title': 'Un film sans date de sortie',
            'poster_path': '/missing.jpg',
          }),
        ],
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(createApp(service));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
      expect(find.textContaining('Sortie :'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Chargement, catalogue pastel et reconstruction sans requête', (
    tester,
  ) async {
    final completer = Completer<List<Movie>>();
    final service = FakeTmdbService(() => completer.future);
    addTearDown(service.dispose);
    await tester.pumpWidget(createApp(service));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Miaou~ Les films arrivent !'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.text('CinéScope')),
    );
    expect(container.read(popularMoviesProvider).isLoading, isTrue);

    completer.complete([movie]);
    await tester.pumpAndSettle();
    expect(find.text('CinéScope'), findsOneWidget);
    expect(find.text('CINÉMA & CÂLINS'), findsNothing);
    expect(
      find.text('Des films à aimer, des étoiles plein les yeux.'),
      findsNothing,
    );
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byType(MovieCard), findsOneWidget);
    expect(find.text('Le Voyage'), findsOneWidget);
    expect(
      container.read(popularMoviesProvider).requireValue.single.title,
      'Le Voyage',
    );
    expect(container.read(popularMoviesProvider).isLoading, isFalse);
    expect(find.text('8.2 / 10'), findsOneWidget);
    expect(find.text('Sortie : 09/10/2026'), findsOneWidget);
    expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
    final context = tester.element(find.byType(MovieCard));
    expect(ShadTheme.of(context).brightness, Brightness.light);
    expect(
      ShadTheme.of(context).colorScheme.background,
      const Color(0xFFFFF5FA),
    );
    expect(
      ShadTheme.of(context).colorScheme.foreground,
      const Color(0xFF68405B),
    );
    expect(ShadTheme.of(context).colorScheme.primary, const Color(0xFFE86AA4));
    expect(find.byType(ShadBadge), findsOneWidget);
    container.read(themeProvider.notifier).setThemeMode(ThemeMode.system);
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Erreur et nouvelle tentative réussie', (tester) async {
    var attempts = 0;
    final service = FakeTmdbService(() async {
      if (attempts++ == 0) throw const TmdbException('Connexion impossible.');
      return [movie];
    });
    addTearDown(service.dispose);
    await tester.pumpWidget(createApp(service));
    await tester.pumpAndSettle();
    expect(find.text('Connexion impossible.'), findsOneWidget);
    expect(
      find.text('Oups, notre petit chat a perdu les films !'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Le Voyage'), findsOneWidget);
    expect(service.calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Un catalogue vide est signalé', (tester) async {
    final service = FakeTmdbService(() async => []);
    addTearDown(service.dispose);
    await tester.pumpWidget(createApp(service));
    await tester.pumpAndSettle();
    expect(find.text('Aucun film trouvé, miaou !'), findsOneWidget);
    expect(find.byType(MovieCard), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Une route inconnue permet de revenir au catalogue', (
    tester,
  ) async {
    final service = FakeTmdbService(() async => [movie]);
    addTearDown(service.dispose);
    await tester.pumpWidget(createApp(service));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(MovieCard));
    GoRouter.of(context).go('/inconnue');
    await tester.pumpAndSettle();
    expect(find.text('Page introuvable'), findsOneWidget);
    await tester.tap(find.text("Retour à l'accueil"));
    await tester.pumpAndSettle();
    expect(find.text('Le Voyage'), findsOneWidget);
    expect(service.calls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
