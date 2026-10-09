import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../models/cinema.dart';
import '../models/cinema_area.dart';
import '../services/cinema_service.dart';
import '../services/cinema_search_service.dart';
import '../services/cinema_enrichment_service.dart';
import 'location_provider.dart';

final cinemaServiceProvider = Provider<CinemaService>((ref) {
  final service = CinemaService(
    loadLocalCopy: () => rootBundle.loadString('assets/data/cinemas_osm.json'),
  );
  ref.onDispose(service.dispose);
  return service;
});

class CinemaAreaNotifier extends Notifier<CinemaArea> {
  @override
  CinemaArea build() => CinemaArea.initial;
  void select(CinemaArea area) => state = area;
}

final cinemaAreaProvider = NotifierProvider<CinemaAreaNotifier, CinemaArea>(
  CinemaAreaNotifier.new,
);

final cinemaSearchServiceProvider = Provider<CinemaSearchService>((ref) {
  final service = CinemaSearchService(gps: ref.watch(geolocatorProvider));
  ref.onDispose(service.dispose);
  return service;
});

final cinemasProvider = FutureProvider<List<Cinema>>(
  (ref) => ref
      .watch(cinemaServiceProvider)
      .fetchCinemas(area: ref.watch(cinemaAreaProvider)),
  retry: (count, error) => null,
);

final cinemaEnrichmentServiceProvider = Provider<CinemaEnrichmentService>((
  ref,
) {
  final service = CinemaEnrichmentService();
  ref.onDispose(service.dispose);
  return service;
});

final enrichedCinemasProvider = FutureProvider<List<Cinema>>((ref) async {
  final service = ref.watch(cinemaEnrichmentServiceProvider);
  final cinemas = await ref.watch(cinemasProvider.future);
  try {
    return await service.enrich(cinemas);
  } catch (_) {
    return cinemas;
  }
}, retry: (count, error) => null);
