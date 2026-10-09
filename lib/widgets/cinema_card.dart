import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/cinema.dart';
import 'cinema_image.dart';

class CinemaCard extends StatelessWidget {
  const CinemaCard({super.key, required this.cinema, this.isGrid = false});
  final Cinema cinema;
  final bool isGrid;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final information = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          cinema.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.h4.copyWith(fontSize: 16, height: 1.25),
        ),
        const SizedBox(height: 6),
        Text(
          cinema.address ?? cinema.city ?? 'Adresse non renseignée',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.muted.copyWith(fontSize: 12, height: 1.4),
        ),
        ...[
          const SizedBox(height: 6),
          Text(
            cinema.displayDescription,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.small.copyWith(fontSize: 12),
          ),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: isGrid ? 0 : 12),
      child: Semantics(
        button: true,
        label: 'Voir la fiche de ${cinema.name}',
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => context.push('/cinemas/${cinema.id}'),
            child: ShadCard(
              padding: const EdgeInsets.all(12),
              child: isGrid
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CinemaImage(cinema: cinema, aspectRatio: 2.4),
                        const SizedBox(height: 12),
                        information,
                      ],
                    )
                  : Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: CinemaImage(cinema: cinema, aspectRatio: 1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: information),
                        const SizedBox(width: 6),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
