import 'dart:async';

import 'package:cinescope/app/cinescope_app.dart';
import 'package:cinescope/models/cinema.dart';
import 'package:cinescope/providers/cinema_provider.dart';
import 'package:cinescope/providers/movie_provider.dart';
import 'package:cinescope/services/cinema_enrichment_service.dart';
import 'package:cinescope/widgets/cinema_card.dart';
import 'package:cinescope/widgets/cinema_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'cinema_enrichment_test.dart'
    show venue, entity, commonsPage, jsonResponse;
import 'widget_test.dart' show FakeTmdbService, movie;

void main() {
  testWidgets('Miniature indisponible : placeholder et crédits conservés', (
    tester,
  ) async {
    final cinema = Cinema(
      id: 'node/1',
      name: 'Simulé',
      latitude: 43.5,
      longitude: 5.4,
      photo: const CinemaPhoto(
        url: 'https://thumb.wikimedia.org/unavailable.jpg',
        sourceUrl: 'https://commons.wikimedia.org/wiki/File:Test.jpg',
        author: 'Auteur de test',
        license: 'CC BY-SA 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by-sa/4.0/',
      ),
    );
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 200, child: CinemaImage(cinema: cinema)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.clapperboard), findsOneWidget);
    expect(find.byIcon(LucideIcons.info), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).headers!['User-Agent'],
      startsWith('CineScope/'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Catalogue immédiat, enrichissement différé, crédits et fiche GPS',
    (tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final ready = Completer<void>();
      var calls = 0;
      final service = CinemaEnrichmentService(
        client: MockClient((request) async {
          calls++;
          await ready.future;
          return request.url.host == 'www.wikidata.org'
              ? jsonResponse({
                  'entities': {'Q123': entity()},
                })
              : jsonResponse({
                  'query': {
                    'pages': [commonsPage()],
                  },
                });
        }),
      );
      final tmdb = FakeTmdbService(() async => [movie]);
      addTearDown(service.dispose);
      addTearDown(tmdb.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cinemasProvider.overrideWith((ref) async => [venue()]),
            cinemaEnrichmentServiceProvider.overrideWithValue(service),
            tmdbServiceProvider.overrideWithValue(tmdb),
          ],
          child: const CinescopeApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinémas'));
      await tester.pumpAndSettle();
      expect(find.byType(CinemaCard), findsOneWidget);
      expect(find.byIcon(LucideIcons.clapperboard), findsOneWidget);
      expect(find.text('Description Wikidata simulée'), findsNothing);
      ready.complete();
      await tester.pumpAndSettle();
      final card = tester.widget<CinemaCard>(find.byType(CinemaCard));
      expect(card.cinema.photo, isNotNull);
      expect(find.text('Description Wikidata simulée'), findsOneWidget);
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byType(CinemaImage),
          matching: find.byType(Image),
        ),
      );
      expect(image.image, isA<NetworkImage>());
      expect(
        (image.image as NetworkImage).url,
        contains('thumb.wikimedia.org'),
      );
      expect(image.fit, BoxFit.cover);
      await tester.tap(find.byIcon(LucideIcons.info));
      await tester.pumpAndSettle();
      expect(find.text('Crédits de la photo'), findsOneWidget);
      expect(find.textContaining('Auteur & Co · CC BY-SA 4.0'), findsOneWidget);
      expect(find.textContaining('Crédit demandé'), findsOneWidget);
      expect(find.textContaining('Vue recadrée'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cinéma simulé'));
      await tester.pumpAndSettle();
      expect(find.text('Latitude : 43.5\nLongitude : 5.4'), findsOneWidget);
      expect(find.text("J'y suis !"), findsOneWidget);
      expect(
        find.textContaining('https://www.wikidata.org/wiki/Q123 · CC0'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Photo : Auteur & Co · CC BY-SA 4.0'),
        findsOneWidget,
      );
      final detailImage = tester.widget<Image>(
        find.descendant(
          of: find.byType(CinemaImage),
          matching: find.byType(Image),
        ),
      );
      expect(detailImage.fit, BoxFit.contain);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(900, 1000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Une image externe sans licence reste un placeholder', (
    tester,
  ) async {
    final original = Cinema(
      id: 'node/1',
      name: 'Sans attribution',
      latitude: 43.5,
      longitude: 5.4,
      imageUrl: 'https://example.com/photo.jpg',
    );
    await tester.pumpWidget(
      ShadApp(
        home: Scaffold(body: CinemaImage(cinema: original)),
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(LucideIcons.clapperboard), findsOneWidget);
    expect(find.text('Illustration générique'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
