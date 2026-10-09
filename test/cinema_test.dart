import 'package:flutter_test/flutter_test.dart';
import 'package:cinescope/models/cinema.dart';

import 'helpers/cinema_fakes.dart';

void main() {
  test(
    'Références propres au lieu et équipements OSM sans confusion de marque',
    () {
      final cinema = Cinema.fromJson({
        ...cinemaJson,
        'tags': {
          'amenity': 'cinema',
          'image': 'File:Test.jpg',
          'wikimedia_commons': 'File:Other.jpg',
          'wikidata': 'Q123',
          'wikipedia': 'fr:Article de test',
          'website': 'https://example.com',
          'screen': '3',
          'cinema:3D': 'yes',
          'wheelchair': 'yes',
          'brand:wikidata': 'Q999',
        },
      });
      expect(cinema.wikidata, 'Q123');
      expect(cinema.imageReference, 'File:Test.jpg');
      expect(cinema.commons, 'File:Other.jpg');
      expect(cinema.wikipedia, 'fr:Article de test');
      expect(cinema.website, 'https://example.com');
      expect(cinema.screens, '3');
      expect(cinema.equipment, 'Projections 3D · Accès en fauteuil roulant');
      expect(
        Cinema.fromJson({
          ...cinemaJson,
          'tags': {
            'amenity': 'cinema',
            'brand:wikidata': 'Q999',
            'name:etymology:wikidata': 'Q888',
          },
        }).wikidata,
        isNull,
      );
      expect(
        Cinema.fromJson({
          ...cinemaJson,
          'tags': {'amenity': 'cinema', 'wikidata': 'not-an-id'},
        }).wikidata,
        isNull,
      );
    },
  );
  test('Une relation utilise le centre fourni par Overpass', () {
    final cinema = Cinema.fromJson({
      'type': 'relation',
      'id': 9,
      'center': {'lat': 43.2, 'lon': 5.3},
      'tags': {'amenity': 'cinema'},
    });
    expect(cinema.id, 'relation/9');
    expect(cinema.latitude, 43.2);
    expect(cinema.longitude, 5.3);
  });
  test('Un nœud OSM fournit ses coordonnées et ses informations', () {
    final cinema = Cinema.fromJson(cinemaJson);
    expect(cinema.id, 'node/1');
    expect(cinema.name, 'Cinéma de test');
    expect(cinema.latitude, 43.5);
    expect(cinema.longitude, 5.4);
    expect(cinema.address, '12 Rue de test, Ville de test');
    expect(cinema.description, 'Description simulée pour les tests.');
    expect(cinema.imageUrl, isNull);
  });
  test(
    'Un bâtiment utilise le centre fourni par Overpass sans données inventées',
    () {
      final cinema = Cinema.fromJson({
        'type': 'way',
        'id': 8,
        'tags': {'amenity': 'cinema'},
        'center': {'lat': 43.2, 'lon': 5.3},
      });
      expect(cinema.id, 'way/8');
      expect(cinema.latitude, 43.2);
      expect(cinema.longitude, 5.3);
      expect(cinema.name, 'Nom indisponible');
      expect(cinema.address, isNull);
      expect(cinema.description, isNull);
    },
  );
  test('Les tags français, adresse complète et image HTTPS sont conservés', () {
    final cinema = Cinema.fromJson({
      ...cinemaJson,
      'tags': {
        'amenity': 'cinema',
        'name:fr': 'Nom français',
        'name': 'Other name',
        'description:fr': 'Résumé français',
        'addr:full': 'Adresse complète',
        'image': 'https://example.com/cinema.jpg',
      },
    });
    expect(cinema.name, 'Nom français');
    expect(cinema.address, 'Adresse complète');
    expect(cinema.description, 'Résumé français');
    expect(cinema.imageUrl, 'https://example.com/cinema.jpg');
  });
  test('Une image invalide ou absente reste absente', () {
    for (final image in [
      null,
      '',
      'File:Example.jpg',
      'http://example.com/a.jpg',
    ]) {
      expect(
        Cinema.fromJson({
          ...cinemaJson,
          'tags': {'amenity': 'cinema', 'image': image},
        }).imageUrl,
        isNull,
      );
    }
  });
  test('Les coordonnées manquantes ou invalides sont refusées', () {
    for (final data in [
      {'type': 'node', 'id': 1},
      {...cinemaJson, 'lat': 100},
      {...cinemaJson, 'lon': double.nan},
      {...cinemaJson, 'type': 'invalid'},
    ]) {
      expect(() => Cinema.fromJson(data), throwsFormatException);
    }
  });
}
