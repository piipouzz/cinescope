import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cinema.dart';
import '../models/cinema_area.dart';
import 'cinema_diagnostics.dart';

class CinemaException implements Exception {
  const CinemaException(this.message);
  final String message;
}

class CinemaCacheEntry {
  const CinemaCacheEntry(this.cinemas, {this.localCopy = false, this.date});
  final List<Cinema> cinemas;
  final bool localCopy;
  final String? date;
}

class CinemaService {
  CinemaService({
    http.Client? client,
    Uri? endpoint,
    DateTime Function()? now,
    this.loadLocalCopy,
    this.requestTimeout = const Duration(seconds: 35),
  }) : _client = client ?? http.Client(),
       _endpoint =
           endpoint ??
           Uri.parse(
             const String.fromEnvironment(
               'OVERPASS_URL',
               defaultValue: 'https://overpass-api.de/api/interpreter',
             ),
           ),
       _now = now ?? DateTime.now;

  static String get query => queryFor(CinemaArea.initial);
  static String queryFor(CinemaArea area) =>
      '[out:json][timeout:25][maxsize:67108864];nwr[amenity=cinema](around:${area.radiusMeters},${area.latitude},${area.longitude});out center tags;\n';

  final http.Client _client;
  final Uri _endpoint;
  final DateTime Function() _now;
  final Future<String> Function()? loadLocalCopy;
  final Duration requestTimeout;
  final _cache = <String, CinemaCacheEntry>{};
  final _pending = <String, Future<List<Cinema>>>{};
  final _manualRetries = <String>{};
  Future<dynamic>? _localData;
  DateTime? _retryAfter;

  bool get usingLocalCopy => usingLocalCopyFor(CinemaArea.initial);
  String? get localCopyDate => localCopyDateFor(CinemaArea.initial);
  bool usingLocalCopyFor(CinemaArea area) =>
      _cache[area.key]?.localCopy ?? false;
  String? localCopyDateFor(CinemaArea area) => _cache[area.key]?.date;
  Duration get retryDelay {
    final delay = _retryAfter?.difference(_now()) ?? Duration.zero;
    return delay.isNegative ? Duration.zero : delay;
  }

  void requestNetworkRetry([CinemaArea area = CinemaArea.initial]) =>
      _manualRetries.add(area.key);

  Future<List<Cinema>> fetchCinemas({CinemaArea area = CinemaArea.initial}) {
    final retry = _manualRetries.remove(area.key);
    final cached = _cache[area.key];
    if (cached != null && (!cached.localCopy || !retry)) {
      cinemaDiagnostic(
        'Overpass',
        'Session cache ${area.key} local=${cached.localCopy}',
      );
      return Future.value(cached.cinemas);
    }
    if (_pending.containsKey(area.key)) return _pending[area.key]!;
    return _pending[area.key] = _fetchWithFallback(area).whenComplete(() {
      _pending.remove(area.key);
    });
  }

  Future<List<Cinema>> _fetchWithFallback(CinemaArea area) async {
    try {
      if (retryDelay > Duration.zero) {
        throw const CinemaException(
          'Une courte pause est nécessaire avant la prochaine recherche. Réessayez à la fin du délai.',
        );
      }
      final cinemas = await _fetch(area);
      _cache[area.key] = CinemaCacheEntry(cinemas);
      return cinemas;
    } on CinemaException {
      final cached = _cache[area.key];
      if (cached != null) return cached.cinemas;
      final load = loadLocalCopy;
      if (load == null) rethrow;
      try {
        final data = await (_localData ??= load().then(jsonDecode));
        final cinemas = List<Cinema>.unmodifiable(
          _parse(
            data,
          ).where((cinema) => area.contains(cinema.latitude, cinema.longitude)),
        );
        if (cinemas.isEmpty) rethrow;
        final snapshot = data['snapshot'];
        final date = snapshot is Map
            ? snapshot['exported_on'] as String?
            : null;
        _cache[area.key] = CinemaCacheEntry(
          cinemas,
          localCopy: true,
          date: date,
        );
        cinemaDiagnostic(
          'Overpass',
          'Local copy ${area.key}: ${cinemas.length} cinemas, $date',
        );
        return cinemas;
      } on CinemaException {
        rethrow;
      } catch (_) {
        _localData = null;
        throw const CinemaException(
          'Le réseau et les données enregistrées sont indisponibles pour cette zone. Réessayez plus tard.',
        );
      }
    }
  }

  Future<List<Cinema>> _fetch(CinemaArea area) async {
    _retryAfter = _now().add(const Duration(seconds: 30));
    try {
      cinemaDiagnostic('Overpass', 'POST $_endpoint data=${queryFor(area)}');
      final response = await _client
          .post(
            _endpoint,
            body: {'data': queryFor(area)},
            headers: const bool.fromEnvironment('dart.library.js_interop')
                ? {}
                : {'User-Agent': 'CineScope/1.0'},
          )
          .timeout(requestTimeout);
      cinemaDiagnostic(
        'Overpass',
        'HTTP ${response.statusCode} retry-after=${response.headers['retry-after']} body=${response.body.substring(0, response.body.length.clamp(0, 500))}',
      );
      if (response.statusCode != 200) {
        if ([429, 503, 504].contains(response.statusCode)) {
          final retry = response.headers['retry-after'];
          final seconds = int.tryParse(retry ?? '');
          final deadline = seconds != null
              ? _now().add(Duration(seconds: seconds))
              : retry == null
              ? null
              : _httpDate(retry);
          if (deadline != null && deadline.isAfter(_retryAfter!)) {
            _retryAfter = deadline;
          }
        }
        throw CinemaException(
          'Les cinémas ne peuvent pas être chargés pour le moment (HTTP ${response.statusCode}). Réessayez plus tard.',
        );
      }
      return _parse(jsonDecode(utf8.decode(response.bodyBytes)));
    } on TimeoutException {
      throw const CinemaException(
        'La recherche de cinémas met trop de temps à répondre. Réessayez.',
      );
    } on http.ClientException {
      throw const CinemaException(
        'Connexion impossible. Vérifiez votre réseau.',
      );
    } on FormatException {
      throw const CinemaException(
        'Les données reçues sont illisibles ou incomplètes.',
      );
    } finally {
      final minimum = _now().add(const Duration(seconds: 30));
      if (_retryAfter!.isBefore(minimum)) _retryAfter = minimum;
    }
  }

  List<Cinema> _parse(dynamic data) {
    if (data is! Map<String, dynamic> ||
        data['elements'] is! List ||
        data.containsKey('remark')) {
      throw const FormatException();
    }
    final cinemas = <String, Cinema>{};
    for (final element in data['elements'] as List) {
      if (element is! Map<String, dynamic>) throw const FormatException();
      try {
        final cinema = Cinema.fromJson(element);
        cinemas[cinema.id] = cinema;
      } on FormatException {
        continue;
      }
    }
    final sorted = cinemas.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(sorted);
  }

  DateTime? _httpDate(String value) {
    final match = RegExp(
      r'^\w+, (\d{2}) (\w{3}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) GMT$',
    ).firstMatch(value);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (match == null || !months.contains(match[2])) return null;
    return DateTime.utc(
      int.parse(match[3]!),
      months.indexOf(match[2]!) + 1,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    );
  }

  void dispose() => _client.close();
}
