import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:cinescope/app/cinescope_app.dart';
import 'package:cinescope/models/cinema_area.dart';
import 'package:cinescope/providers/cinema_provider.dart';
import 'package:cinescope/providers/movie_provider.dart';
import 'package:cinescope/services/cinema_search_service.dart';
import 'package:cinescope/services/cinema_service.dart';
import 'package:cinescope/widgets/cinema_card.dart';

import 'helpers/cinema_fakes.dart';
import 'widget_test.dart' show FakeTmdbService, movie;

http.Response cinemas(String name, {double lat = 43.5, double lon = 5.4}) =>
    http.Response(
      jsonEncode({
        'elements': [
          {
            ...cinemaJson,
            'lat': lat,
            'lon': lon,
            'tags': {...cinemaJson['tags'] as Map, 'name': name},
          },
        ],
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Widget discoveryApp(
  CinemaService service,
  CinemaSearchService search,
  FakeTmdbService tmdb,
) => ProviderScope(
  overrides: [
    cinemaServiceProvider.overrideWithValue(service),
    cinemaSearchServiceProvider.overrideWithValue(search),
    tmdbServiceProvider.overrideWithValue(tmdb),
  ],
  child: const CinescopeApp(),
);

void main() {
  testWidgets(
    'Recherche explicite, choix de ville, changement de zone et cache lors du retour',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.utc(2026);
      var cityCalls = 0;
      final queries = <String>[];
      final gps = FakeGps();
      final service = CinemaService(
        now: () => now,
        client: MockClient((request) async {
          final query = request.bodyFields['data']!;
          queries.add(query);
          return query.contains('48.8589')
              ? cinemas('Cinéma parisien simulé', lat: 48.8589, lon: 2.347)
              : cinemas('Cinéma aixois simulé');
        }),
      );
      final search = CinemaSearchService(
        gps: gps,
        client: MockClient((request) async {
          cityCalls++;
          return http.Response(
            jsonEncode([
              {
                'nom': 'Paris',
                'codeDepartement': '75',
                'centre': {
                  'coordinates': [2.347, 48.8589],
                },
              },
              {
                'nom': 'Parisot',
                'codeDepartement': '81',
                'centre': {
                  'coordinates': [1.8, 43.7],
                },
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final tmdb = FakeTmdbService(() => Future.value([movie]));
      addTearDown(service.dispose);
      addTearDown(search.dispose);
      addTearDown(tmdb.dispose);
      await tester.pumpWidget(discoveryApp(service, search, tmdb));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      expect(gps.positionRequests, 0);
      expect(cityCalls, 0);
      await tester.enterText(find.byType(EditableText), 'Paris');
      await tester.pumpAndSettle();
      expect(cityCalls, 0);
      expect(queries.length, 1);
      now = now.add(const Duration(seconds: 31));
      await tester.tap(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();
      expect(find.text('Choisir une ville'), findsOneWidget);
      expect(queries.length, 1);
      await tester.tap(find.text('Paris (75)'));
      await tester.pumpAndSettle();
      expect(find.text('Paris (75)'), findsOneWidget);
      expect(find.text('Cinéma parisien simulé'), findsOneWidget);
      expect(find.text('Cinéma aixois simulé'), findsNothing);
      expect(queries.last, contains('around:10000,48.8589,2.347'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CinemaCard)),
      );
      container.read(cinemaAreaProvider.notifier).select(CinemaArea.initial);
      await tester.pumpAndSettle();
      expect(find.text('Cinéma aixois simulé'), findsOneWidget);
      expect(queries.length, 2);
      await tester.tap(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paris (75)'));
      await tester.pumpAndSettle();
      expect(cityCalls, 1);
      expect(queries.length, 2);
      expect(find.text('Cinéma parisien simulé'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Autour de moi : aucune permission au démarrage, GPS à la demande, responsive sans requête',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.utc(2026);
      var calls = 0;
      final gps = FakeGps();
      final service = CinemaService(
        now: () => now,
        client: MockClient((request) async {
          calls++;
          if (calls == 2) {
            expect(
              request.bodyFields['data'],
              contains('around:10000,43.5,5.4'),
            );
          }
          return cinemas('Cinéma simulé');
        }),
      );
      final search = CinemaSearchService(gps: gps);
      final tmdb = FakeTmdbService(() => Future.value([movie]));
      addTearDown(service.dispose);
      addTearDown(search.dispose);
      addTearDown(tmdb.dispose);
      await tester.pumpWidget(discoveryApp(service, search, tmdb));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      expect(gps.positionRequests, 0);
      expect(gps.permissionRequests, 0);
      now = now.add(const Duration(seconds: 31));
      await tester.tap(find.text('Autour de moi'));
      await tester.pumpAndSettle();
      expect(gps.positionRequests, 1);
      expect(calls, 2);
      expect(find.text('Autour de moi'), findsNWidgets(2));
      for (final width in [600.0, 900.0, 1200.0, 390.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpAndSettle();
        expect(find.byType(width < 600 ? ListView : GridView), findsOneWidget);
        expect(calls, 2);
        expect(gps.positionRequests, 1);
        expect(tester.takeException(), isNull);
      }
      gps.enabled = false;
      await tester.tap(find.widgetWithText(ShadButton, 'Autour de moi'));
      await tester.pumpAndSettle();
      expect(find.textContaining('GPS est désactivé'), findsOneWidget);
      expect(gps.positionRequests, 1);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Zone en cours de chargement ou en erreur : aucune ancienne carte affichée',
    (tester) async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final response = Completer<http.Response>();
      final service = CinemaService(
        now: () => now,
        client: MockClient((request) async {
          calls++;
          return calls == 1 ? cinemas('Ancien cinéma simulé') : response.future;
        }),
      );
      final search = CinemaSearchService(gps: FakeGps());
      final tmdb = FakeTmdbService(() => Future.value([movie]));
      addTearDown(service.dispose);
      addTearDown(search.dispose);
      addTearDown(tmdb.dispose);
      await tester.pumpWidget(discoveryApp(service, search, tmdb));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CinemaCard)),
      );
      now = now.add(const Duration(seconds: 31));
      container
          .read(cinemaAreaProvider.notifier)
          .select(
            const CinemaArea(
              label: 'Paris (75)',
              latitude: 48.8589,
              longitude: 2.347,
            ),
          );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Paris (75)'), findsOneWidget);
      expect(find.text('Ancien cinéma simulé'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      response.complete(http.Response('', 500));
      await tester.pumpAndSettle();
      expect(find.textContaining('HTTP 500'), findsOneWidget);
      expect(find.byType(CinemaCard), findsNothing);
      container.read(cinemaAreaProvider.notifier).select(CinemaArea.initial);
      await tester.pumpAndSettle();
      expect(find.text('Ancien cinéma simulé'), findsOneWidget);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
