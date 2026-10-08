import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/movie_provider.dart';
import '../services/tmdb_service.dart';
import '../widgets/movie_card.dart';
import '../widgets/cat_mascot.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.secondary,
                          theme.colorScheme.card,
                        ],
                      ),
                      border: Border.all(color: theme.colorScheme.border),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Row(
                        children: [
                          Expanded(
                            child: Text(
                              'CinéScope',
                              style: theme.textTheme.h2.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CatMascot(
                            size: constraints.maxWidth < 400 ? 88 : 104,
                            removePadding: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Films populaires',
                          style: theme.textTheme.h4.copyWith(
                            fontSize: 19,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ExcludeSemantics(
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.sparkles,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              LucideIcons.heart,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _buildCatalogue(context, ref)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogue(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(popularMoviesProvider);
    return movies.when(
      skipLoadingOnRefresh: false,
      loading: () => _buildStatus(
        context,
        ref,
        'Miaou~ Les films arrivent !',
        detail: 'Votre prochaine découverte se prépare.',
        isLoading: true,
      ),
      error: (error, stackTrace) {
        final message = error is TmdbException
            ? error.message
            : error is StateError
            ? 'Configurez TMDB_API_KEY pour charger les films.'
            : 'Impossible de charger les films. Réessayez.';
        return _buildStatus(
          context,
          ref,
          'Oups, notre petit chat a perdu les films !',
          detail: message,
        );
      },
      data: (movies) {
        if (movies.isEmpty) {
          return _buildStatus(
            context,
            ref,
            'Aucun film trouvé, miaou !',
            detail: 'Revenez bientôt pour de nouvelles découvertes.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          itemCount: movies.length,
          itemBuilder: (context, index) =>
              MovieCard(key: ValueKey(movies[index].id), movie: movies[index]),
        );
      },
    );
  }

  Widget _buildStatus(
    BuildContext context,
    WidgetRef ref,
    String message, {
    String? detail,
    bool isLoading = false,
  }) {
    final theme = ShadTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ShadCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CatMascot(size: 72),
                const SizedBox(height: 16),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.h4.copyWith(
                      fontSize: 18,
                      height: 1.5,
                    ),
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    detail,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.muted.copyWith(height: 1.6),
                  ),
                ],
                const SizedBox(height: 20),
                if (isLoading)
                  SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: theme.colorScheme.foreground,
                      semanticsLabel: 'Chargement des films',
                    ),
                  )
                else
                  ShadButton(
                    onPressed: () => ref.invalidate(popularMoviesProvider),
                    child: const Text('Réessayer'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
