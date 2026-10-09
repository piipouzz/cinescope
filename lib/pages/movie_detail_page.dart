import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/movie.dart';
import '../widgets/cat_mascot.dart';

class MovieDetailPage extends StatelessWidget {
  const MovieDetailPage({super.key, required this.movie});

  final Movie? movie;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final selectedMovie = movie;

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
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.arrowLeft, size: 18),
                            SizedBox(width: 8),
                            Text('Retour'),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const CatMascot(size: 56, removePadding: true),
                    ],
                  ),
                ),
                Expanded(
                  child: selectedMovie == null
                      ? Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: ShadCard(
                              child: Text(
                                'Film indisponible. Revenez au catalogue pour sélectionner un film.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.p,
                              ),
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final poster = ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: _buildPoster(context, selectedMovie),
                            );
                            final information = _buildInformation(
                              context,
                              selectedMovie,
                            );
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                              child: constraints.maxWidth >= 700
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(width: 280, child: poster),
                                        const SizedBox(width: 24),
                                        Expanded(child: information),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Center(child: poster),
                                        const SizedBox(height: 24),
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

  Widget _buildPoster(BuildContext context, Movie movie) {
    final theme = ShadTheme.of(context);
    final placeholder = ColoredBox(
      color: theme.colorScheme.muted,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.imageOff,
              color: theme.colorScheme.mutedForeground,
            ),
            const SizedBox(height: 12),
            Text('Affiche indisponible', style: theme.textTheme.muted),
          ],
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: movie.posterPath == null
            ? placeholder
            : Image.network(
                'https://image.tmdb.org/t/p/w500${movie.posterPath}',
                fit: BoxFit.cover,
                semanticLabel: 'Affiche de ${movie.title}',
                errorBuilder: (context, error, stackTrace) => placeholder,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );
  }

  Widget _buildInformation(BuildContext context, Movie movie) {
    final theme = ShadTheme.of(context);
    final date = movie.releaseDate;
    final dateLabel = date == null
        ? 'Date de sortie indisponible'
        : 'Sortie : ${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return ShadCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(movie.title, style: theme.textTheme.h2.copyWith(fontSize: 28)),
          const SizedBox(height: 16),
          ShadBadge.secondary(
            child: Text('${movie.voteAverage.toStringAsFixed(1)} / 10'),
          ),
          const SizedBox(height: 16),
          Text(dateLabel, style: theme.textTheme.muted),
          const SizedBox(height: 24),
          Text('Synopsis', style: theme.textTheme.h4),
          const SizedBox(height: 12),
          Text(
            movie.overview.trim().isEmpty
                ? 'Synopsis indisponible.'
                : movie.overview,
            style: theme.textTheme.p.copyWith(height: 1.7),
          ),
        ],
      ),
    );
  }
}
