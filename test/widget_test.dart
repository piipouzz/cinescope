import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:cinescope/app/cinescope_app.dart';
import 'package:cinescope/models/movie.dart';
import 'package:cinescope/pages/movie_detail_page.dart';
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
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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

  for (final width in [390.0, 599.0, 600.0, 800.0, 900.0, 1200.0, 1440.0]) {
    testWidgets('Catalogue responsive à $width pixels sans débordement', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final service = FakeTmdbService(
        () async => List.generate(
          8,
          (index) => Movie.fromJson({
            'id': index,
            'title': 'Un très long titre de film pour tester les cartes $index',
            'vote_average': 8.2,
            'release_date': '2026-10-09',
          }),
        ),
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(createApp(service));
      await tester.pumpAndSettle();
      if (width < 600) {
        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
      } else {
        expect(find.byType(ListView), findsNothing);
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          delegate.crossAxisCount,
          width >= 1200 ? 4 : (width >= 900 ? 3 : 2),
        );
        expect(
          tester.widget<MovieCard>(find.byType(MovieCard).first).isGrid,
          isTrue,
        );
      }
      expect(find.text('CinéScope'), findsOneWidget);
      expect(find.text('8.2 / 10'), findsWidgets);
      expect(find.text('Sortie : 09/10/2026'), findsWidgets);
      final poster = find.descendant(
        of: find.byType(MovieCard).first,
        matching: find.byType(AspectRatio),
      );
      final posterSize = tester.getSize(poster);
      expect(posterSize.width / posterSize.height, closeTo(2 / 3, 0.001));
      expect(tester.takeException(), isNull);
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Redimensionner le catalogue conserve les données sans requête', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeTmdbService(() async => [movie]);
    addTearDown(service.dispose);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(createApp(service));
    await tester.pumpAndSettle();
    expect(find.byType(ListView), findsOneWidget);
    for (final width in [800.0, 1000.0, 1400.0, 390.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(find.byType(width < 600 ? ListView : GridView), findsOneWidget);
      expect(find.text('Le Voyage'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(service.calls, 1);
    }
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

  for (final width in [390.0, 800.0]) {
    testWidgets('Navigation vers le film choisi et retour à $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = Movie.fromJson({
        'id': 99,
        'title': 'Le film choisi',
        'overview': 'Un voyage au cœur des montagnes.',
        'poster_path': '/test.jpg',
        'release_date': '2026-10-09',
        'vote_average': 7.8,
      });
      final service = FakeTmdbService(() async => [selected, movie]);
      addTearDown(service.dispose);
      await tester.pumpWidget(createApp(service));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey(99)));
      await tester.pumpAndSettle();
      final page = tester.widget<MovieDetailPage>(find.byType(MovieDetailPage));
      expect(page.movie, same(selected));
      expect(find.text('Le film choisi'), findsOneWidget);
      expect(find.text(selected.overview), findsOneWidget);
      expect(find.text('Sortie : 09/10/2026'), findsOneWidget);
      expect(find.text('7.8 / 10'), findsOneWidget);
      final poster = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is NetworkImage,
        ),
      );
      expect(
        (poster.image as NetworkImage).url,
        'https://image.tmdb.org/t/p/w500/test.jpg',
      );
      expect(poster.semanticLabel, 'Affiche de Le film choisi');
      expect(tester.takeException(), isNull);
      expect(service.calls, 1);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieDetailPage), findsNothing);
      expect(find.byType(width < 600 ? ListView : GridView), findsOneWidget);
      expect(find.byType(MovieCard), findsNWidgets(2));
      expect(service.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Le retour conserve la position du catalogue', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final service = FakeTmdbService(
      () async => List.generate(
        20,
        (index) => Movie.fromJson({'id': index, 'title': 'Film $index'}),
      ),
    );
    addTearDown(service.dispose);
    await tester.pumpWidget(createApp(service));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey(10)), 200);
    await Scrollable.ensureVisible(
      tester.element(find.byKey(const ValueKey(10))),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    final offset = position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey(10)));
    await tester.pumpAndSettle();
    expect(find.byType(MovieDetailPage), findsOneWidget);
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(position.pixels, offset);
    expect(find.text('Film 10'), findsOneWidget);
    expect(service.calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final extra in [null, 'objet incorrect']) {
    testWidgets('La fiche sans Movie valide reste accessible ($extra)', (
      tester,
    ) async {
      final service = FakeTmdbService(() async => [movie]);
      addTearDown(service.dispose);
      await tester.pumpWidget(createApp(service));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(MovieCard)))
          .go('/movie/42', extra: extra);
      await tester.pumpAndSettle();
      expect(find.textContaining('Film indisponible.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieCard), findsOneWidget);
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final width in [320.0, 800.0]) {
    testWidgets('Synopsis complet et données absentes à $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final synopsis =
          '${List.filled(40, 'Une longue aventure à travers les montagnes et les océans.').join('\n\n')}\nFin du synopsis.';
      final service = FakeTmdbService(
        () async => [
          Movie.fromJson({
            'id': 55,
            'title': 'Un film avec un très long synopsis',
            'overview': synopsis,
          }),
        ],
      );
      addTearDown(service.dispose);
      await tester.pumpWidget(createApp(service));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MovieCard));
      await tester.pumpAndSettle();
      expect(find.text('Affiche indisponible'), findsOneWidget);
      expect(find.text('Date de sortie indisponible'), findsOneWidget);
      final synopsisWidget = tester.widget<Text>(find.text(synopsis));
      expect(synopsisWidget.maxLines, isNull);
      expect(synopsisWidget.data, endsWith('Fin du synopsis.'));
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(scrollable.position.maxScrollExtent, greaterThan(1000));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text(synopsis)).bottom,
        lessThanOrEqualTo(900),
      );
      expect(tester.takeException(), isNull);
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Un synopsis absent est signalé dans la fiche', (tester) async {
    final service = FakeTmdbService(() async => [movie]);
    addTearDown(service.dispose);
    await tester.pumpWidget(createApp(service));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(MovieCard),
        matching: find.byType(AspectRatio),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synopsis indisponible.'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
