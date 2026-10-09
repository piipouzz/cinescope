import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/movie.dart';

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.isGrid = false});

  final Movie movie;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final date = movie.releaseDate;
    final dateLabel = date == null
        ? null
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final placeholder = ColoredBox(
      color: theme.colorScheme.muted,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.imageOff,
              color: theme.colorScheme.mutedForeground,
              semanticLabel: 'Affiche indisponible',
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: Text(
                'Affiche\nindisponible',
                textAlign: TextAlign.center,
                style: theme.textTheme.small.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );

    final poster = AspectRatio(
      aspectRatio: 2 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: movie.posterPath == null
            ? placeholder
            : Image.network(
                'https://image.tmdb.org/t/p/w342${movie.posterPath}',
                fit: BoxFit.cover,
                semanticLabel: 'Affiche de ${movie.title}',
                errorBuilder: (context, error, stackTrace) => placeholder,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );

    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          maxLines: isGrid ? 2 : null,
          overflow: isGrid ? TextOverflow.ellipsis : null,
          style: theme.textTheme.h4.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        ShadBadge.secondary(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(
                  LucideIcons.star,
                  size: 14,
                  color: theme.colorScheme.foreground,
                ),
              ),
              Text('${movie.voteAverage.toStringAsFixed(1)} / 10'),
            ],
          ),
        ),
        if (dateLabel != null) ...[
          const SizedBox(height: 12),
          Text(
            'Sortie : $dateLabel',
            style: theme.textTheme.muted.copyWith(fontSize: 12, height: 1.5),
          ),
        ],
      ],
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isGrid ? 0 : 20),
      child: Semantics(
        button: true,
        label: 'Voir la fiche de ${movie.title}',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/movie/${movie.id}', extra: movie),
            child: ShadCard(
              padding: const EdgeInsets.all(16),
              child: isGrid
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        poster,
                        const SizedBox(height: 16),
                        information,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 88, child: poster),
                        const SizedBox(width: 16),
                        Expanded(child: information),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
