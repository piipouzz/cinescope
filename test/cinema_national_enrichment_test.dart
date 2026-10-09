import 'package:cinescope/models/cinema.dart';
import 'package:cinescope/services/cinema_enrichment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'cinema_enrichment_test.dart' show jsonResponse, commonsPage, entity;

Cinema localVenue(double lat, double lon) => Cinema(
  id: 'node/123',
  name: 'Cinéma de test',
  latitude: lat,
  longitude: lon,
  wikipedia: 'fr:Article explicitement lié',
  city: 'Commune de test',
);

Map<String, Object> article(double lat, double lon) => {
  'query': {
    'pages': [
      {
        'title': 'Article explicitement lié',
        'extract': 'Introduction factuelle de l’article lié au lieu.',
        'coordinates': [
          {'lat': lat, 'lon': lon, 'globe': 'earth'},
        ],
        'pageprops': {'page_image_free': 'Cinema test.jpg'},
      },
    ],
  },
};

void main() {
  test('Un article proche associé à un autre identifiant est rejeté', () async {
    final response = article(43.5, 5.4);
    final page = ((response['query'] as Map)['pages'] as List).single as Map;
    (page['pageprops'] as Map)['wikibase_item'] = 'Q999';
    final service = CinemaEnrichmentService(
      client: MockClient((request) async {
        if (request.url.host == 'www.wikidata.org') {
          return jsonResponse({
            'entities': {'Q123': entity(image: false)},
          });
        }
        expect(request.url.host, 'fr.wikipedia.org');
        return jsonResponse(response);
      }),
    );
    addTearDown(service.dispose);
    const venue = Cinema(
      id: 'node/1',
      name: 'Test',
      latitude: 43.5,
      longitude: 5.4,
      wikidata: 'Q123',
      wikipedia: 'fr:Article explicitement lié',
    );
    final result = (await service.enrich([venue])).single;
    expect(result.description, 'Description Wikidata simulée');
    expect(result.descriptionSource, 'https://www.wikidata.org/wiki/Q123');
    expect(result.photo, isNull);
  });

  test(
    'Même traitement à Toulouse, Lyon et Lille : article lié, photo et cache',
    () async {
      for (final point in [
        (43.6045, 1.444),
        (45.764, 4.8357),
        (50.6292, 3.0573),
      ]) {
        var calls = 0;
        final service = CinemaEnrichmentService(
          client: MockClient((request) async {
            calls++;
            if (request.url.host == 'fr.wikipedia.org') {
              expect(
                request.url.queryParameters['titles'],
                'Article explicitement lié',
              );
              return jsonResponse(article(point.$1, point.$2));
            }
            expect(request.url.host, 'commons.wikimedia.org');
            return jsonResponse({
              'query': {
                'pages': [commonsPage()],
              },
            });
          }),
        );
        addTearDown(service.dispose);
        final original = localVenue(point.$1, point.$2);
        final enriched = (await service.enrich([original])).single;
        expect(enriched.description, startsWith('Introduction factuelle'));
        expect(
          enriched.descriptionSource,
          startsWith('https://fr.wikipedia.org/wiki/'),
        );
        expect(enriched.photo!.author, 'Auteur & Co');
        expect(enriched.latitude, original.latitude);
        expect(enriched.longitude, original.longitude);
        await service.enrich([original]);
        expect(calls, 2);
      }
    },
  );

  test(
    'Article éloigné ou homonyme : ni description ni photo substituées',
    () async {
      final service = CinemaEnrichmentService(
        client: MockClient((request) async {
          expect(request.url.host, 'fr.wikipedia.org');
          return jsonResponse(article(48.8566, 2.3522));
        }),
      );
      addTearDown(service.dispose);
      final result = (await service.enrich([localVenue(43.6045, 1.444)]))
          .single;
      expect(result.description, isNull);
      expect(result.photo, isNull);
      expect(
        result.displayDescriptionSource,
        'https://www.openstreetmap.org/node/123',
      );
    },
  );

  test('Article d’homonymie à proximité ignoré', () async {
    final response = article(43.6045, 1.444);
    final page = ((response['query'] as Map)['pages'] as List).single as Map;
    (page['pageprops'] as Map)['disambiguation'] = '';
    final service = CinemaEnrichmentService(
      client: MockClient((_) async => jsonResponse(response)),
    );
    addTearDown(service.dispose);
    final result = (await service.enrich([localVenue(43.6045, 1.444)])).single;
    expect(result.description, isNull);
    expect(result.photo, isNull);
  });

  test(
    'Sans article : synthèse OSM sourcée et aucune recherche libre par nom',
    () async {
      final service = CinemaEnrichmentService(
        client: MockClient((_) async {
          fail('Aucun appel Wikimedia sans référence explicite');
        }),
      );
      addTearDown(service.dispose);
      const venue = Cinema(
        id: 'way/8',
        name: 'Cinéma de test',
        latitude: 43.6045,
        longitude: 1.444,
        city: 'Toulouse',
        address: 'Adresse de test',
        screens: '3',
        equipment: 'Accès en fauteuil roulant',
      );
      final result = (await service.enrich([venue])).single;
      expect(result.displayDescription, contains('à Toulouse'));
      expect(
        result.displayDescription,
        contains('Nombre de salles renseigné : 3'),
      );
      expect(result.displayDescription, contains('Accès en fauteuil roulant'));
      expect(result.displayDescription, isNot(contains('ouvert')));
      expect(
        result.displayDescriptionSource,
        'https://www.openstreetmap.org/way/8',
      );
      expect(result.photo, isNull);
    },
  );
}
