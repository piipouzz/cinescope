import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/cinema.dart';
import '../providers/cinema_provider.dart';
import '../providers/location_provider.dart';
import '../services/location_service.dart';
import '../widgets/cat_mascot.dart';
import '../widgets/cinema_image.dart';
import '../widgets/cinema_source_notice.dart';

class CinemaDetailRoute extends ConsumerWidget {
  const CinemaDetailRoute({super.key, required this.cinemaId});
  final String cinemaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enriched = ref.watch(enrichedCinemasProvider);
    return ref
        .watch(cinemasProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, stack) => const CinemaDetailPage(cinema: null),
          data: (original) {
            final cinemas = !enriched.isLoading && !enriched.hasError
                ? enriched.value ?? original
                : original;
            final matches = cinemas.where((cinema) => cinema.id == cinemaId);
            return CinemaDetailPage(
              cinema: matches.isEmpty ? null : matches.first,
            );
          },
        );
  }
}

class CinemaDetailPage extends ConsumerStatefulWidget {
  const CinemaDetailPage({super.key, required this.cinema});
  final Cinema? cinema;

  @override
  ConsumerState<CinemaDetailPage> createState() => _CinemaDetailPageState();
}

class _CinemaDetailPageState extends ConsumerState<CinemaDetailPage> {
  bool _checking = false;
  CinemaDistance? _distance;
  String? _error;

  Future<void> _checkPresence() async {
    final cinema = widget.cinema;
    if (cinema == null || _checking) return;
    setState(() {
      _checking = true;
      _distance = null;
      _error = null;
    });
    try {
      final distance = await ref
          .read(locationServiceProvider)
          .checkDistance(cinema);
      if (mounted) setState(() => _distance = distance);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is LocationException
              ? error.message
              : 'Impossible de vérifier votre position. Réessayez.';
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cinema = widget.cinema;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      ShadButton.outline(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go('/cinemas'),
                        child: const Text('Retour'),
                      ),
                      const Spacer(),
                      const CatMascot(size: 56, removePadding: true),
                    ],
                  ),
                ),
                Expanded(
                  child: cinema == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Cinéma indisponible. Revenez au catalogue pour sélectionner un cinéma.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final image = ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: CinemaImage(
                                cinema: cinema,
                                fit: BoxFit.contain,
                                aspectRatio: cinema.photo == null ? 3 : 4 / 3,
                              ),
                            );
                            final information = _information(context, cinema);
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: constraints.maxWidth >= 700
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(width: 280, child: image),
                                        const SizedBox(width: 20),
                                        Expanded(child: information),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Center(child: image),
                                        const SizedBox(height: 16),
                                        information,
                                      ],
                                    ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _information(BuildContext context, Cinema cinema) {
    final theme = ShadTheme.of(context);
    final distance = _distance;
    final distanceLabel = distance == null
        ? null
        : distance.meters < 1000
        ? '${distance.meters.toStringAsFixed(0)} m'
        : '${(distance.meters / 1000).toStringAsFixed(1)} km';
    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cinema.name, style: theme.textTheme.h2.copyWith(fontSize: 28)),
          if (ref
              .read(cinemaServiceProvider)
              .usingLocalCopyFor(ref.watch(cinemaAreaProvider))) ...[
            const SizedBox(height: 8),
            const CinemaSourceNotice(),
          ],
          const SizedBox(height: 16),
          Text(
            cinema.address ?? 'Adresse non renseignée',
            style: theme.textTheme.muted,
          ),
          ...[
            const SizedBox(height: 16),
            Text(
              cinema.displayDescription,
              style: theme.textTheme.p.copyWith(height: 1.6),
            ),
            ...[
              const SizedBox(height: 6),
              SelectableText(
                'Source : ${cinema.displayDescriptionSource}${cinema.displayDescriptionSource.contains('wikidata.org')
                    ? ' · CC0'
                    : cinema.displayDescriptionSource.contains('openstreetmap.org')
                    ? ' · ODbL'
                    : cinema.displayDescriptionSource.contains('wikipedia.org')
                    ? ' · Wikipédia, CC BY-SA 4.0'
                    : ''}',
                style: theme.textTheme.muted.copyWith(fontSize: 11),
              ),
            ],
          ],
          if (cinema.screens != null) ...[
            const SizedBox(height: 12),
            Text(
              'Nombre de salles (OSM) : ${cinema.screens}',
              style: theme.textTheme.small,
            ),
          ],
          if (cinema.equipment != null) ...[
            const SizedBox(height: 8),
            Text(cinema.equipment!, style: theme.textTheme.small),
          ],
          if (cinema.website != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              'Site : ${cinema.website}',
              style: theme.textTheme.small,
            ),
          ],
          const SizedBox(height: 20),
          Text('Coordonnées GPS', style: theme.textTheme.h4),
          const SizedBox(height: 8),
          SelectableText(
            'Latitude : ${cinema.latitude}\nLongitude : ${cinema.longitude}',
          ),
          const SizedBox(height: 24),
          Text('Vérifier ma proximité', style: theme.textTheme.h4),
          const SizedBox(height: 8),
          Text(
            'Seuil : 200 mètres. Votre position est utilisée uniquement lors de cette vérification.',
            style: theme.textTheme.muted,
          ),
          const SizedBox(height: 16),
          ShadButton(
            enabled: !_checking,
            onPressed: _checkPresence,
            child: Flexible(
              child: Text("J'y suis !", style: theme.textTheme.small),
            ),
          ),
          if (_checking) ...[
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              semanticsLabel: 'Recherche de votre position',
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: theme.textTheme.p.copyWith(
                  color: theme.colorScheme.destructive,
                ),
              ),
            ),
          ],
          if (distance != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                'Distance estimée : $distanceLabel',
                style: theme.textTheme.h4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              distance.isNearby
                  ? 'Vous êtes à proximité du cinéma (200 m ou moins).'
                  : 'Vous êtes à plus de 200 m du cinéma.',
            ),
            const SizedBox(height: 8),
            Text(
              'Précision GPS annoncée : ${distance.accuracy.toStringAsFixed(0)} m. La distance est calculée à vol d’oiseau vers le point OpenStreetMap.',
              style: theme.textTheme.muted,
            ),
          ],
          const SizedBox(height: 24),
          Text(
            '© les contributeurs OpenStreetMap · ODbL',
            style: theme.textTheme.small,
          ),
          const SizedBox(height: 8),
          const SelectableText('https://www.openstreetmap.org/copyright'),
          if (cinema.photo != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Photo : ${cinema.photo!.author} · ${cinema.photo!.license}\n'
              '${cinema.photo!.sourceName}\n'
              '${cinema.photo!.credit}\n${cinema.photo!.sourceUrl}\n${cinema.photo!.licenseUrl}',
              style: theme.textTheme.small,
            ),
          ],
        ],
      ),
    );
  }
}
