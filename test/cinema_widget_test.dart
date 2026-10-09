import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:cinescope/app/cinescope_app.dart';
import 'package:cinescope/models/cinema.dart';
import 'package:cinescope/pages/cinema_detail_page.dart';
import 'package:cinescope/providers/cinema_provider.dart';
import 'package:cinescope/providers/location_provider.dart';
import 'package:cinescope/providers/movie_provider.dart';
import 'package:cinescope/services/cinema_service.dart';
import 'package:cinescope/services/location_service.dart';
import 'package:cinescope/widgets/cinema_card.dart';
import 'package:cinescope/widgets/cinema_image.dart';
import 'package:cinescope/widgets/movie_card.dart';

import 'helpers/cinema_fakes.dart';
import 'widget_test.dart' show FakeTmdbService, movie;

Widget cinemaApp(CinemaService service, FakeGps gps, FakeTmdbService tmdb) =>
    ProviderScope(
      overrides: [
        cinemaServiceProvider.overrideWithValue(service),
        locationServiceProvider.overrideWithValue(
          LocationService(platform: gps),
        ),
        tmdbServiceProvider.overrideWithValue(tmdb),
      ],
      child: const CinescopeApp(),
    );

void main() {
  testWidgets(
    'Fiches sans texte éditorial : synthèse OSM sans débordement en liste et grille',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const venue = Cinema(
        id: 'node/999',
        name: 'Cinéma de test',
        latitude: 43.6045,
        longitude: 1.444,
        city: 'Toulouse',
        address:
            'Une adresse de test suffisamment longue pour revenir à la ligne',
        screens: '3',
      );
      final tmdb = FakeTmdbService(() async => [movie]);
      addTearDown(tmdb.dispose);
      tester.view.physicalSize = const Size(320, 900);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cinemasProvider.overrideWith((ref) async => [venue]),
            enrichedCinemasProvider.overrideWith((ref) async => [venue]),
            tmdbServiceProvider.overrideWithValue(tmdb),
          ],
          child: const CinescopeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      for (final width in [320.0, 600.0, 900.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(find.text(venue.displayDescription), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Largeur $width');
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Overpass indisponible : asset local, fiche, GPS et relance manuelle',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.utc(2026, 10, 9);
      var calls = 0;
      final service = CinemaService(
        now: () => now,
        client: MockClient((request) async {
          calls++;
          return calls == 1
              ? http.Response('', 500)
              : http.Response(
                  jsonEncode({
                    'elements': [cinemaJson],
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
        }),
        loadLocalCopy: () =>
            rootBundle.loadString('assets/data/cinemas_osm.json'),
      );
      final gps = FakeGps();
      final tmdb = FakeTmdbService(() async => [movie]);
      addTearDown(service.dispose);
      addTearDown(tmdb.dispose);
      await tester.pumpWidget(cinemaApp(service, gps, tmdb));
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.sparkles), findsNothing);
      expect(find.byIcon(LucideIcons.heart), findsNothing);
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      expect(find.text('Données enregistrées · Mode hors ligne'), findsNothing);
      expect(find.byType(CinemaCard), findsWidgets);
      expect(service.usingLocalCopy, isTrue);
      expect(calls, 1);
      final card = tester.widget<CinemaCard>(find.byType(CinemaCard).first);
      final cinema = card.cinema;
      await tester.tap(find.byType(CinemaCard).first);
      await tester.pumpAndSettle();
      expect(find.text('Données enregistrées · Mode hors ligne'), findsNothing);
      expect(
        find.text(
          'Latitude : ${cinema.latitude}\nLongitude : ${cinema.longitude}',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text("J'y suis !"));
      await tester.tap(find.text("J'y suis !"));
      await tester.pumpAndSettle();
      expect(find.textContaining('Distance estimée'), findsOneWidget);
      expect(gps.positionRequests, 1);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Réessayer en ligne'), findsNothing);
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is Icon &&
              widget.semanticLabel == 'Provenance et date des données',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Provenance des données'), findsOneWidget);
      expect(find.textContaining('du 2026-10-09'), findsOneWidget);
      await tester.tap(find.text('Actualiser les données'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Données enregistrées · Mode hors ligne'), findsNothing);
      expect(find.text('Cinéma de test'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('Informations absentes et photo en erreur : fiche utilisable', (
    tester,
  ) async {
    final service = CinemaService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'elements': [
              {
                ...cinemaJson,
                'tags': {
                  'amenity': 'cinema',
                  'image': 'https://example.com/missing.jpg',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final gps = FakeGps();
    final tmdb = FakeTmdbService(() async => [movie]);
    addTearDown(service.dispose);
    addTearDown(tmdb.dispose);
    await tester.pumpWidget(cinemaApp(service, gps, tmdb));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cinémas'));
    await tester.pumpAndSettle();
    expect(find.text('Adresse non renseignée'), findsOneWidget);
    expect(find.byIcon(LucideIcons.clapperboard), findsOneWidget);
    expect(find.text('Illustration générique'), findsNothing);
    await tester.tap(find.byType(CinemaImage));
    await tester.pumpAndSettle();
    expect(find.text('Nom indisponible'), findsOneWidget);
    expect(find.text('Adresse non renseignée'), findsOneWidget);
    expect(find.text('Description non renseignée.'), findsNothing);
    expect(find.byIcon(LucideIcons.clapperboard), findsOneWidget);
    expect(find.text('Illustration générique'), findsNothing);
    expect(find.textContaining('Vous êtes à proximité'), findsNothing);
    expect(gps.positionRequests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [320.0, 390.0, 599.0, 600.0, 800.0, 1000.0, 1200.0]) {
    testWidgets('Catalogue et navigation cinémas à $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var calls = 0;
      final service = CinemaService(
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'elements': List.generate(
                8,
                (index) => {...cinemaJson, 'id': index + 1},
              ),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final gps = FakeGps();
      final tmdb = FakeTmdbService(() async => [movie]);
      addTearDown(service.dispose);
      addTearDown(tmdb.dispose);
      await tester.pumpWidget(cinemaApp(service, gps, tmdb));
      await tester.pumpAndSettle();
      expect(find.byType(MovieCard), findsOneWidget);
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      expect(find.byType(width < 600 ? ListView : GridView), findsOneWidget);
      if (width >= 600) {
        final delegate =
            tester.widget<GridView>(find.byType(GridView)).gridDelegate
                as SliverGridDelegateWithFixedCrossAxisCount;
        expect(
          delegate.crossAxisCount,
          width >= 1200 ? 4 : (width >= 900 ? 3 : 2),
        );
      }
      expect(find.byType(CinemaCard), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('node/1')));
      await tester.pumpAndSettle();
      expect(find.byType(CinemaDetailPage), findsOneWidget);
      expect(find.text('Cinéma de test'), findsOneWidget);
      expect(find.text('Description simulée pour les tests.'), findsOneWidget);
      expect(find.byType(CinemaImage), findsOneWidget);
      expect(find.text('Latitude : 43.5\nLongitude : 5.4'), findsOneWidget);
      expect(gps.positionRequests, 0);
      expect(find.textContaining('Vous êtes à proximité'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(find.byType(CinemaCard), findsWidgets);
      await tester.tap(find.text('Films'));
      await tester.pumpAndSettle();
      expect(find.byType(MovieCard), findsOneWidget);
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(tmdb.calls, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Chargement, erreur API et relance du catalogue', (tester) async {
    final response = Completer<http.Response>();
    var calls = 0;
    var now = DateTime.utc(2026);
    final service = CinemaService(
      now: () => now,
      client: MockClient((request) {
        calls++;
        return calls == 1
            ? response.future
            : Future.value(
                http.Response(
                  jsonEncode({
                    'elements': [cinemaJson],
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
              );
      }),
    );
    final tmdb = FakeTmdbService(() async => [movie]);
    addTearDown(service.dispose);
    addTearDown(tmdb.dispose);
    await tester.pumpWidget(cinemaApp(service, FakeGps(), tmdb));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cinémas'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    response.complete(http.Response('', 500));
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    now = now.add(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.byType(CinemaCard), findsOneWidget);
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Une liste vide est signalée', (tester) async {
    final service = CinemaService(
      client: MockClient(
        (request) async => http.Response('{"elements":[]}', 200),
      ),
    );
    final tmdb = FakeTmdbService(() async => [movie]);
    addTearDown(service.dispose);
    addTearDown(tmdb.dispose);
    await tester.pumpWidget(cinemaApp(service, FakeGps(), tmdb));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cinémas'));
    await tester.pumpAndSettle();
    expect(find.text('Aucun cinéma trouvé dans cette zone.'), findsOneWidget);
    expect(find.byType(CinemaCard), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Route directe sans objet : aucun crash et retour aux cinémas', (
    tester,
  ) async {
    final service = CinemaService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'elements': [cinemaJson],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final tmdb = FakeTmdbService(() async => [movie]);
    addTearDown(service.dispose);
    addTearDown(tmdb.dispose);
    await tester.pumpWidget(cinemaApp(service, FakeGps(), tmdb));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(MovieCard))).go('/cinemas/node/999');
    await tester.pumpAndSettle();
    expect(find.textContaining('Cinéma indisponible.'), findsOneWidget);
    expect(find.text("J'y suis !"), findsNothing);
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(find.byType(CinemaCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'J’y suis : attente GPS, distance, erreur et nouvelle vérification',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = CinemaService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'elements': [cinemaJson],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final tmdb = FakeTmdbService(() async => [movie]);
      final position = Completer<Position>();
      final gps = FakeGps()..locate = () => position.future;
      addTearDown(service.dispose);
      addTearDown(tmdb.dispose);
      await tester.pumpWidget(cinemaApp(service, gps, tmdb));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CinemaCard));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text("J'y suis !"));
      await tester.tap(find.text("J'y suis !"));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Distance estimée'), findsNothing);
      final button = find.ancestor(
        of: find.text("J'y suis !"),
        matching: find.byType(ShadButton),
      );
      expect(tester.widget<ShadButton>(button).enabled, isFalse);
      position.complete(testPosition());
      await tester.pumpAndSettle();
      expect(find.text('Distance estimée : 0 m'), findsOneWidget);
      expect(find.textContaining('Vous êtes à proximité'), findsOneWidget);
      expect(gps.positionRequests, 1);
      gps.permission = LocationPermission.deniedForever;
      await tester.tap(find.text("J'y suis !"));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Localisation refusée définitivement.'),
        findsOneWidget,
      );
      expect(find.textContaining('Vous êtes à proximité'), findsNothing);
      expect(find.textContaining('Distance estimée'), findsNothing);
      gps.permission = LocationPermission.whileInUse;
      gps.locate = () async => testPosition(latitude: 43.51);
      await tester.tap(find.text("J'y suis !"));
      await tester.pumpAndSettle();
      expect(find.textContaining('km'), findsOneWidget);
      expect(find.text('Vous êtes à plus de 200 m du cinéma.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
