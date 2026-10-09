import 'dart:async';
import 'dart:convert';

import 'package:cinescope/models/cinema.dart';
import 'package:cinescope/services/cinema_enrichment_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:cinescope/services/cinema_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Cinema venue({
  String? qid = 'Q123',
  String? commons,
  String? image,
  String? description,
  double lat = 43.5,
}) => Cinema(
  id: 'node/1',
  name: 'Cinéma simulé',
  latitude: lat,
  longitude: 5.4,
  wikidata: qid,
  commons: commons,
  imageReference: image,
  description: description,
);

Map<String, dynamic> entity({
  String id = 'Q123',
  double lat = 43.5,
  bool image = true,
  bool coordinates = true,
}) => {
  'id': id,
  'descriptions': {
    'fr': {'value': 'Description Wikidata simulée'},
  },
  'claims': {
    if (image)
      'P18': [
        {
          'rank': 'normal',
          'mainsnak': {
            'snaktype': 'value',
            'datavalue': {'value': 'Cinema test.jpg'},
          },
        },
      ],
    if (coordinates)
      'P625': [
        {
          'rank': 'normal',
          'mainsnak': {
            'snaktype': 'value',
            'datavalue': {
              'value': {
                'latitude': lat,
                'longitude': 5.4,
                'globe': 'http://www.wikidata.org/entity/Q2',
              },
            },
          },
        },
      ],
  },
};

Map<String, dynamic> commonsPage({
  String title = 'File:Cinema test.jpg',
  bool license = true,
  String? source,
  String? gpsLat,
}) => {
  'title': title,
  'imageinfo': [
    {
      'url':
          'https://upload.wikimedia.org/wikipedia/commons/a/ab/Cinema_test.jpg',
      'thumburl': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/a/ab/Cinema_test.jpg/1280px-Cinema_test.jpg',
      'descriptionurl':
          source ?? 'https://commons.wikimedia.org/wiki/File:Cinema_test.jpg',
      'mime': 'image/jpeg',
      'extmetadata': {
        'Artist': {'value': '<a href="/wiki/User:Test">Auteur &amp; Co</a>'},
        'Credit': {'value': '<span>Travail personnel</span>'},
        'Attribution': {'value': 'Crédit demandé'},
        if (license) 'LicenseShortName': {'value': 'CC BY-SA 4.0'},
        if (license)
          'LicenseUrl': {
            'value': 'https://creativecommons.org/licenses/by-sa/4.0/',
          },
        if (gpsLat != null) 'GPSLatitude': {'value': gpsLat},
        if (gpsLat != null) 'GPSLongitude': {'value': '5.4'},
      },
    },
  ],
};

http.Response jsonResponse(Object data) => http.Response(
  jsonEncode(data),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Secours local : identifiant Renoir, enrichissement, cache après panne Overpass', () async {
    var now = DateTime.utc(2026);
    final osm = CinemaService(
      now: () => now,
      client: MockClient((_) async => http.Response('', 500)),
      loadLocalCopy: () =>
          rootBundle.loadString('assets/data/cinemas_osm.json'),
    );
    addTearDown(osm.dispose);
    final local = await osm.fetchCinemas();
    final renoir = local.singleWhere((c) => c.wikidata == 'Q42294666');
    final item = entity(id: 'Q42294666', lat: renoir.latitude);
    item['claims']['P625'][0]['mainsnak']['datavalue']['value']['longitude'] =
        renoir.longitude;
    var calls = 0;
    final service = CinemaEnrichmentService(
      client: MockClient((request) async {
        calls++;
        expect(request.url.queryParameters.containsKey('maxlag'), isFalse);
        return request.url.host == 'www.wikidata.org'
            ? jsonResponse({
                'entities': {'Q42294666': item},
              })
            : jsonResponse({
                'query': {
                  'pages': [commonsPage()],
                },
              });
      }),
    );
    addTearDown(service.dispose);
    final enriched = (await service.enrich([renoir])).single;
    expect(enriched.photo!.url, startsWith('https://thumb.wikimedia.org/'));
    expect(enriched.photo!.license, 'CC BY-SA 4.0');
    expect(enriched.latitude, renoir.latitude);
    now = now.add(const Duration(seconds: 31));
    osm.requestNetworkRetry();
    expect(await osm.fetchCinemas(), same(local));
    expect((await service.enrich([renoir])).single.photo, same(enriched.photo));
    expect(calls, 2);
  });

  test('Une panne Wikimedia expire sans relance automatique ni cache négatif permanent', () async {
    var now = DateTime.utc(2026);
    var calls = 0;
    final service = CinemaEnrichmentService(
      now: () => now,
      client: MockClient((request) async {
        calls++;
        if (calls == 1) {
          return jsonResponse({
            'error': {'code': 'maxlag', 'info': 'temporarily unavailable'},
          });
        }
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
    addTearDown(service.dispose);
    expect((await service.enrich([venue()])).single.photo, isNull);
    expect((await service.enrich([venue()])).single.photo, isNull);
    expect(calls, 1);
    now = now.add(const Duration(seconds: 61));
    expect((await service.enrich([venue()])).single.photo, isNotNull);
    expect(calls, 3);
  });
  test(
    'Identifiant OSM, coordonnées cohérentes, P18, description et crédits',
    () async {
      final calls = <http.Request>[];
      final service = CinemaEnrichmentService(
        client: MockClient((request) async {
          calls.add(request);
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
      addTearDown(service.dispose);
      final result = (await service.enrich([venue()])).single;
      expect(result.latitude, 43.5);
      expect(result.longitude, 5.4);
      expect(result.description, 'Description Wikidata simulée');
      expect(result.descriptionSource, 'https://www.wikidata.org/wiki/Q123');
      expect(result.photo!.author, 'Auteur & Co');
      expect(result.photo!.credit, 'Crédit demandé · Travail personnel');
      expect(result.photo!.license, 'CC BY-SA 4.0');
      expect(
        result.photo!.licenseUrl,
        contains('creativecommons.org/licenses/by-sa/4.0/'),
      );
      expect(result.photo!.sourceUrl, contains('File:Cinema_test.jpg'));
      expect(calls, hasLength(2));
      expect(calls.last.url.queryParameters['titles'], 'File:Cinema test.jpg');
    },
  );

  test(
    'Sans identifiant ni fichier, aucune recherche par nom et aucun appel',
    () async {
      final service = CinemaEnrichmentService(
        client: MockClient((_) async {
          fail('Aucune recherche par nom ne doit être faite');
        }),
      );
      addTearDown(service.dispose);
      final result = (await service.enrich([venue(qid: null)])).single;
      expect(result.photo, isNull);
      expect(result.description, isNull);
    },
  );

  test(
    'Description OSM prioritaire et description sans photo conservées',
    () async {
      final service = CinemaEnrichmentService(
        client: MockClient(
          (_) async => jsonResponse({
            'entities': {'Q123': entity(image: false)},
          }),
        ),
      );
      addTearDown(service.dispose);
      expect(
        (await service.enrich([venue(description: 'Description OSM')]))
            .single
            .description,
        'Description OSM',
      );
      final result = (await service.enrich([venue()])).single;
      expect(result.photo, isNull);
      expect(result.description, 'Description Wikidata simulée');
    },
  );

  test('Mauvais identifiant, établissement éloigné et absence de coordonnées rejetés', () async {
    for (final incorrect in [
      entity(id: 'Q999'),
      entity(lat: 48.8),
      entity(coordinates: false),
    ]) {
      var calls = 0;
      final service = CinemaEnrichmentService(
        client: MockClient((_) async {
          calls++;
          return jsonResponse({
            'entities': {'Q123': incorrect},
          });
        }),
      );
      final result = (await service.enrich([venue()])).single;
      expect(result.photo, isNull);
      expect(result.description, isNull);
      expect(calls, 1);
      service.dispose();
    }
  });

  test(
    'Fichier Commons OSM explicite sans Wikidata, catégorie ignorée',
    () async {
      var calls = 0;
      final service = CinemaEnrichmentService(
        client: MockClient((request) async {
          calls++;
          expect(request.url.host, 'commons.wikimedia.org');
          return jsonResponse({
            'query': {
              'pages': [commonsPage()],
            },
          });
        }),
      );
      addTearDown(service.dispose);
      expect(
        (await service.enrich([venue(qid: null, commons: 'Category:Cinemas')]))
            .single
            .photo,
        isNull,
      );
      expect(calls, 0);
      expect(
        (await service.enrich([
          venue(qid: null, commons: 'File:cinema_test.jpg'),
        ])).single.photo,
        isNotNull,
      );
      expect(calls, 1);
    },
  );

  test(
    'Les formes image OSM Commons sont résolues sans recherche libre',
    () async {
      for (final reference in [
        'File:Cinema test.jpg',
        'https://commons.wikimedia.org/wiki/File:Cinema_test.jpg',
        'https://commons.wikimedia.org/wiki/Special:FilePath/Cinema_test.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/a/ab/Cinema_test.jpg',
      ]) {
        final service = CinemaEnrichmentService(
          client: MockClient((request) async {
            expect(
              request.url.queryParameters['titles'],
              'File:Cinema test.jpg',
            );
            return jsonResponse({
              'query': {
                'pages': [commonsPage()],
              },
            });
          }),
        );
        expect(
          (await service.enrich([venue(qid: null, image: reference)]))
              .single
              .photo,
          isNotNull,
        );
        service.dispose();
      }
    },
  );

  test(
    'Photo sans licence, page non correspondante ou GPS éloigné rejetée',
    () async {
      for (final page in [
        commonsPage(license: false),
        commonsPage(title: 'File:Other.jpg'),
        commonsPage(
          source: 'https://commons.wikimedia.org/wiki/File:Other.jpg',
        ),
        commonsPage(gpsLat: '48.8'),
      ]) {
        final service = CinemaEnrichmentService(
          client: MockClient(
            (_) async => jsonResponse({
              'query': {
                'pages': [page],
              },
            }),
          ),
        );
        expect(
          (await service.enrich([
            venue(qid: null, commons: 'File:Cinema test.jpg'),
          ])).single.photo,
          isNull,
        );
        service.dispose();
      }
    },
  );

  test(
    'Erreurs HTTP, limitation, JSON et timeout ne masquent aucun cinéma',
    () async {
      for (final status in [500, 429, 503, 200]) {
        var calls = 0;
        final service = CinemaEnrichmentService(
          client: MockClient((_) async {
            calls++;
            return http.Response('invalid JSON', status);
          }),
        );
        final original = venue();
        final result = (await service.enrich([original])).single;
        expect(result.id, original.id);
        expect(result.photo, isNull);
        await service.enrich([original]);
        expect(calls, 1);
        service.dispose();
      }
      final service = CinemaEnrichmentService(
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) => Completer<http.Response>().future),
      );
      addTearDown(service.dispose);
      expect(await service.enrich([venue()]), hasLength(1));
    },
  );

  test(
    'Échec Commons préserve la description Wikidata et ses coordonnées OSM',
    () async {
      final service = CinemaEnrichmentService(
        client: MockClient(
          (request) async => request.url.host == 'www.wikidata.org'
              ? jsonResponse({
                  'entities': {'Q123': entity()},
                })
              : http.Response('', 500),
        ),
      );
      addTearDown(service.dispose);
      final result = (await service.enrich([venue()])).single;
      expect(result.photo, isNull);
      expect(result.description, isNotNull);
      expect(result.latitude, 43.5);
    },
  );

  test('Cache des entités et médias et regroupement simultané', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final service = CinemaEnrichmentService(
      client: MockClient((request) async {
        calls++;
        return request.url.host == 'www.wikidata.org'
            ? pending.future
            : jsonResponse({
                'query': {
                  'pages': [commonsPage()],
                },
              });
      }),
    );
    addTearDown(service.dispose);
    final a = service.enrich([venue()]);
    final b = service.enrich([venue()]);
    pending.complete(
      jsonResponse({
        'entities': {'Q123': entity()},
      }),
    );
    expect((await a).single.photo, isNotNull);
    expect((await b).single.photo, isNotNull);
    await service.enrich([venue()]);
    expect(calls, 2);
    expect((await service.enrich([venue(lat: 48.8)])).single.photo, isNull);
    expect(calls, 2);
  });

  test(
    'Groupes Commons de cinq et arrêt des appels après limitation',
    () async {
      var calls = 0;
      final service = CinemaEnrichmentService(
        client: MockClient((request) async {
          calls++;
          expect(
            request.url.queryParameters['titles']!.split('|'),
            hasLength(5),
          );
          return http.Response('', 429, headers: {'retry-after': '120'});
        }),
      );
      addTearDown(service.dispose);
      final cinemas = List.generate(
        12,
        (i) => Cinema(
          id: 'node/$i',
          name: 'Simulé $i',
          latitude: 43.5,
          longitude: 5.4,
          commons: 'File:Test $i.jpg',
        ),
      );
      expect(await service.enrich(cinemas), hasLength(12));
      expect(calls, 1);
    },
  );

  test(
    'Données malformées et absence de fichier restent facultatives',
    () async {
      final service = CinemaEnrichmentService(
        client: MockClient(
          (_) async => jsonResponse({
            'entities': {
              'Q123': {'id': 'Q123', 'claims': 'invalid'},
            },
          }),
        ),
      );
      addTearDown(service.dispose);
      expect((await service.enrich([venue()])).single.photo, isNull);
    },
  );
}
