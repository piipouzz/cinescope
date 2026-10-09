import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cinema.dart';
import '../models/cinema_area.dart';
import 'cinema_diagnostics.dart';

class CinemaEnrichmentService {
  CinemaEnrichmentService({
    http.Client? client,
    DateTime Function()? now,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now;

  final http.Client _client;
  final DateTime Function() _now;
  final Duration timeout;
  final _entities = <String, dynamic>{};
  final _photos = <String, CinemaPhoto?>{};
  final _photoCoordinates = <String, (double, double)>{};
  final _requests = <Uri, Future<Map<String, dynamic>?>>{};
  final _blockedUntil = <String, DateTime>{};
  Future<void> _queue = Future.value();

  Future<List<Cinema>> enrich(List<Cinema> cinemas) async {
    try {
      return await _enrich(cinemas);
    } catch (error) {
      cinemaDiagnostic('enrichment', 'Processing failed: $error');
      return cinemas;
    }
  }

  Future<List<Cinema>> _enrich(List<Cinema> cinemas) async {
    final ids =
        cinemas
            .where(
              (cinema) => cinema.photo == null || cinema.description == null,
            )
            .map((c) => c.wikidata)
            .whereType<String>()
            .toSet()
            .where((id) => !_entities.containsKey(id))
            .toList()
          ..sort();
    for (var offset = 0; offset < ids.length; offset += 50) {
      final batch = ids.skip(offset).take(50).toList();
      final data = await _get('www.wikidata.org', {
        'action': 'wbgetentities',
        'ids': batch.join('|'),
        'props': 'claims|descriptions|sitelinks',
        'languages': 'fr',
      });
      final entities = data?['entities'];
      if (data == null) continue;
      for (final id in batch) {
        _entities[id] = entities is Map ? entities[id] : null;
      }
    }
    final files = <String, String>{};
    final descriptions = <String, String>{};
    final sources = <String, String>{};
    for (final cinema in cinemas) {
      final entity = _entities[cinema.wikidata];
      final matches = _matches(cinema, entity);
      final explicit =
          _file(cinema.commons) ??
          _file(cinema.imageReference ?? cinema.imageUrl);
      final image = matches ? _claim(entity, 'P18') : null;
      final file = explicit ?? (image is String ? _file('File:$image') : null);
      if (file != null) files[cinema.id] = file;
      if (matches) {
        final value = _read(entity, ['descriptions', 'fr', 'value']);
        if (value is String && value.trim().isNotEmpty) {
          descriptions[cinema.id] = value.trim();
          sources[cinema.id] =
              'https://www.wikidata.org/wiki/${cinema.wikidata}';
        }
      }
    }
    // Only follow an explicit OSM article or a geographically verified entity.
    // Never guess an establishment from its name.
    for (final cinema in cinemas) {
      final entity = _entities[cinema.wikidata];
      final linkedTitle = _read(entity, ['sitelinks', 'frwiki', 'title']);
      final reference = cinema.wikipedia;
      final title = reference != null && reference.startsWith('fr:')
          ? reference.substring(3)
          : _matches(cinema, entity) && linkedTitle is String
          ? linkedTitle
          : null;
      if (title == null || title.isEmpty || title.contains('|')) continue;
      final data = await _get('fr.wikipedia.org', {
        'action': 'query',
        'formatversion': '2',
        'prop': 'extracts|pageprops|coordinates',
        'titles': title,
        'redirects': '1',
        'exintro': '1',
        'explaintext': '1',
        'ppprop': 'wikibase_item|disambiguation|page_image_free',
        'coprimary': 'primary',
      });
      final pages = _read(data, ['query', 'pages']);
      if (pages is! List || pages.length != 1 || pages.first is! Map) continue;
      final page = pages.first as Map;
      final properties = page['pageprops'];
      if (page['missing'] == true ||
          (properties is Map && properties.containsKey('disambiguation'))) {
        continue;
      }
      final articleId = _read(page, ['pageprops', 'wikibase_item']);
      final coordinates = page['coordinates'];
      final point = coordinates is List && coordinates.isNotEmpty
          ? coordinates.first
          : null;
      final nearby =
          point is Map &&
          point['lat'] is num &&
          point['lon'] is num &&
          point['globe'] == 'earth' &&
          CinemaArea(
            label: cinema.name,
            latitude: cinema.latitude,
            longitude: cinema.longitude,
            radiusMeters: 300,
          ).contains(
            (point['lat'] as num).toDouble(),
            (point['lon'] as num).toDouble(),
          );
      final verifiedEntity =
          articleId == cinema.wikidata && _matches(cinema, entity);
      if (!nearby && !verifiedEntity) continue;
      if (cinema.wikidata != null && articleId != cinema.wikidata) continue;
      // An explicitly linked, nearby article can also provide a free image.
      final articleImage = _read(page, ['pageprops', 'page_image_free']);
      if (!files.containsKey(cinema.id) && articleImage is String) {
        final file = _file('File:$articleImage');
        if (file != null) files[cinema.id] = file;
      }
      final extract = page['extract'];
      final articleTitle = page['title'];
      if (extract is String &&
          extract.trim().isNotEmpty &&
          articleTitle is String) {
        descriptions[cinema.id] = extract.trim();
        sources[cinema.id] = Uri.https(
          'fr.wikipedia.org',
          '/wiki/${articleTitle.replaceAll(' ', '_')}',
        ).toString();
      }
    }
    final missing =
        files.values.toSet().where((f) => !_photos.containsKey(f)).toList()
          ..sort();
    for (var offset = 0; offset < missing.length; offset += 5) {
      final batch = missing.skip(offset).take(5).toList();
      final data = await _get('commons.wikimedia.org', {
        'action': 'query',
        'formatversion': '2',
        'prop': 'imageinfo',
        'titles': batch.join('|'),
        'iiprop': 'url|mime|extmetadata',
        'iiurlwidth': '1280',
        'iiextmetadatalanguage': 'fr',
        'iiextmetadatafilter': 'Artist|Credit|Attribution|LicenseShortName|LicenseUrl|Restrictions|GPSLatitude|GPSLongitude',
      });
      if (data == null) continue;
      for (final file in batch) {
        _photos[file] = null;
      }
      final pages = _read(data, ['query', 'pages']);
      if (pages is List) {
        for (final page in pages) {
          if (page is! Map || page['missing'] == true) continue;
          final title = _file(page['title']);
          if (title != null && batch.contains(title)) {
            _photos[title] = _photo(page);
            final infos = page['imageinfo'];
            if (infos is List && infos.isNotEmpty) {
              final lat = double.tryParse(
                _plain(
                  _read(infos.first, ['extmetadata', 'GPSLatitude', 'value']),
                ),
              );
              final lon = double.tryParse(
                _plain(
                  _read(infos.first, ['extmetadata', 'GPSLongitude', 'value']),
                ),
              );
              if (lat != null && lon != null) {
                _photoCoordinates[title] = (lat, lon);
              }
            }
          }
        }
      }
    }
    return List.unmodifiable(
      cinemas.map((cinema) {
        final coordinates = _photoCoordinates[files[cinema.id]];
        final nearby =
            coordinates == null ||
            CinemaArea(
              label: cinema.name,
              latitude: cinema.latitude,
              longitude: cinema.longitude,
              radiusMeters: 300,
            ).contains(coordinates.$1, coordinates.$2);
        final photo =
            cinema.photo ?? (nearby ? _photos[files[cinema.id]] : null);
        cinemaDiagnostic(
          'enrichment',
          '${cinema.id} qid=${cinema.wikidata} file=${files[cinema.id]} photo=${photo?.url ?? 'none'}',
        );
        return cinema.enriched(
          photo: photo,
          description: descriptions[cinema.id],
          source: sources[cinema.id],
        );
      }),
    );
  }

  bool _matches(Cinema cinema, dynamic entity) {
    if (entity is! Map ||
        entity['id'] != cinema.wikidata ||
        entity.containsKey('missing')) {
      return false;
    }
    final coordinates = _claim(entity, 'P625');
    if (coordinates is! Map ||
        coordinates['latitude'] is! num ||
        coordinates['longitude'] is! num ||
        coordinates['globe'] != 'http://www.wikidata.org/entity/Q2') {
      return false;
    }
    return CinemaArea(
      label: cinema.name,
      latitude: cinema.latitude,
      longitude: cinema.longitude,
      radiusMeters: 300,
    ).contains(
      (coordinates['latitude'] as num).toDouble(),
      (coordinates['longitude'] as num).toDouble(),
    );
  }

  dynamic _claim(dynamic entity, String property) {
    final claims = _read(entity, ['claims', property]);
    if (claims is! List) return null;
    final valid = claims
        .whereType<Map>()
        .where(
          (c) =>
              c['rank'] != 'deprecated' &&
              c['mainsnak'] is Map &&
              c['mainsnak']['snaktype'] == 'value',
        )
        .toList();
    valid.sort(
      (a, b) => (a['rank'] == 'preferred' ? 0 : 1).compareTo(
        b['rank'] == 'preferred' ? 0 : 1,
      ),
    );
    return valid.isEmpty
        ? null
        : _read(valid.first, ['mainsnak', 'datavalue', 'value']);
  }

  dynamic _read(dynamic value, List<String> keys) {
    for (final key in keys) {
      if (value is! Map) return null;
      value = value[key];
    }
    return value;
  }

  String? _file(dynamic value) {
    if (value is! String || value.length > 500) return null;
    var title = value.trim();
    final uri = Uri.tryParse(title);
    if (uri != null && uri.scheme == 'https') {
      if (uri.host == 'commons.wikimedia.org' &&
          uri.path.startsWith('/wiki/File:')) {
        title = Uri.decodeComponent(uri.path.substring(6));
      } else if (uri.host == 'commons.wikimedia.org' &&
          uri.path.startsWith('/wiki/Special:FilePath/')) {
        title =
            'File:${Uri.decodeComponent(uri.path.substring('/wiki/Special:FilePath/'.length))}';
      } else if (uri.host == 'upload.wikimedia.org' &&
          uri.path.startsWith('/wikipedia/commons/') &&
          !uri.path.contains('/thumb/')) {
        title = 'File:${uri.pathSegments.last}';
      } else {
        return null;
      }
    }
    if (!title.startsWith('File:') ||
        title.contains('|') ||
        title.contains('\n')) {
      return null;
    }
    title = title.replaceAll('_', ' ');
    return title.length > 5
        ? 'File:${title[5].toUpperCase()}${title.substring(6)}'
        : null;
  }

  CinemaPhoto? _photo(Map page) {
    final infos = page['imageinfo'];
    if (infos is! List || infos.isEmpty || infos.first is! Map) return null;
    final info = infos.first as Map;
    if (!['image/jpeg', 'image/png', 'image/webp'].contains(info['mime'])) {
      return null;
    }
    final metadata = info['extmetadata'];
    if (metadata is! Map) return null;
    String text(String key) =>
        _plain(metadata[key] is Map ? metadata[key]['value'] : null);
    final author = text('Artist');
    final license = text('LicenseShortName');
    final licenseUrl = text('LicenseUrl')
        .replaceFirst(RegExp(r'^http:'), 'https:');
    final source = info['descriptionurl'];
    final url = info['thumburl'] ?? info['url'];
    bool trusted(dynamic v, Set<String> hosts) {
      final uri = v is String ? Uri.tryParse(v) : null;
      return uri != null && uri.scheme == 'https' && hosts.contains(uri.host);
    }

    if (author.isEmpty ||
        license.isEmpty ||
        text('Restrictions').isNotEmpty ||
        !trusted(licenseUrl, {
          'creativecommons.org',
          'www.creativecommons.org',
          'www.gnu.org',
          'gnu.org',
        }) ||
        !trusted(source, {'commons.wikimedia.org'}) ||
        _file(source) != _file(page['title']) ||
        !trusted(url, {'upload.wikimedia.org', 'thumb.wikimedia.org'})) {
      return null;
    }
    return CinemaPhoto(
      url: url as String,
      sourceUrl: source as String,
      author: author,
      license: license,
      licenseUrl: licenseUrl,
      credit: [
        text('Attribution'),
        text('Credit'),
      ].where((v) => v.isNotEmpty).join(' · '),
    );
  }

  String _plain(dynamic value) {
    if (value is! String) return '';
    return value
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|[0-9]+);'), (m) {
          final s = m[1]!;
          final n = int.tryParse(
            s.startsWith('x') ? s.substring(1) : s,
            radix: s.startsWith('x') ? 16 : 10,
          );
          return n != null && n > 0 && n <= 0x10ffff
              ? String.fromCharCode(n)
              : '';
        })
        .trim();
  }

  Future<Map<String, dynamic>?> _get(
    String host,
    Map<String, String> parameters,
  ) {
    final uri = Uri.https(host, '/w/api.php', {
      ...parameters,
      'format': 'json',
      'origin': '*',
    });
    return _requests.putIfAbsent(uri, () {
      final result = _queue.then((_) => _fetch(uri));
      _queue = result.then((_) {});
      result.then((data) {
        if (data == null) _requests.remove(uri);
      });
      return result;
    });
  }

  Future<Map<String, dynamic>?> _fetch(Uri uri) async {
    if (_blockedUntil[uri.host]?.isAfter(_now()) ?? false) {
      cinemaDiagnostic('enrichment', '${uri.host}: cooldown');
      return null;
    }
    try {
      cinemaDiagnostic('enrichment', 'GET $uri');
      final response = await _client
          .get(
            uri,
            headers: const bool.fromEnvironment('dart.library.js_interop')
                ? {}
                : {
                    'User-Agent':
                        'CineScope/1.0 (educational cinema catalogue)',
                  },
          )
          .timeout(timeout);
      cinemaDiagnostic(
        'enrichment',
        '${uri.host}: HTTP ${response.statusCode}',
      );
      if (response.statusCode != 200) {
        final delay = int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
        _blockedUntil[uri.host] = _now().add(
          Duration(seconds: delay < 60 ? 60 : delay),
        );
        return null;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! Map<String, dynamic> || data.containsKey('error')) {
        cinemaDiagnostic(
          'enrichment',
          'API error: ${data is Map ? data['error'] : 'invalid JSON'}',
        );
        _blockedUntil[uri.host] = _now().add(const Duration(minutes: 1));
        return null;
      }
      return data;
    } catch (error) {
      cinemaDiagnostic('enrichment', '${uri.host}: $error');
      _blockedUntil[uri.host] = _now().add(const Duration(minutes: 1));
      return null;
    }
  }

  void dispose() => _client.close();
}
