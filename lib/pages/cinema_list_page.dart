import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/cinema_provider.dart';
import '../services/cinema_service.dart';
import '../widgets/cat_mascot.dart';
import '../widgets/cinema_card.dart';
import '../widgets/cinema_search_controls.dart';
import '../widgets/cinema_source_notice.dart';

class CinemaListPage extends ConsumerWidget {
  const CinemaListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final area = ref.watch(cinemaAreaProvider);
    final enriched = ref.watch(enrichedCinemasProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CinéScope',
                              style: theme.textTheme.h2.copyWith(fontSize: 26),
                            ),
                            Text(
                              'Une séance près de vous',
                              style: theme.textTheme.muted.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const CatMascot(size: 64, removePadding: true),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: CinemaSearchControls(),
                ),
                Expanded(
                  child: ref
                      .watch(cinemasProvider)
                      .when(
                        skipLoadingOnRefresh: true,
                        skipLoadingOnReload: false,
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Chargement des cinémas',
                          ),
                        ),
                        error: (error, stack) => Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: ShadCard(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    LucideIcons.cloudOff,
                                    color: theme.colorScheme.primary,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Les cinémas se font attendre',
                                    style: theme.textTheme.h4,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    error is CinemaException
                                        ? error.message
                                        : 'Impossible de charger cette zone.',
                                    style: theme.textTheme.muted,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  const CinemaRetryButton(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        data: (original) {
                          final cinemas =
                              !enriched.isLoading && !enriched.hasError
                              ? enriched.value ?? original
                              : original;
                          return Column(
                            children: [
                              Expanded(
                                child: cinemas.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'Aucun cinéma trouvé dans cette zone.',
                                        ),
                                      )
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (constraints.maxWidth < 600) {
                                            return ListView.builder(
                                              key: PageStorageKey(
                                                'cinemas-${area.key}-list',
                                              ),
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    16,
                                                    8,
                                                    16,
                                                    16,
                                                  ),
                                              itemCount: cinemas.length,
                                              itemBuilder: (context, index) =>
                                                  CinemaCard(
                                                    key: ValueKey(
                                                      cinemas[index].id,
                                                    ),
                                                    cinema: cinemas[index],
                                                  ),
                                            );
                                          }
                                          final columns =
                                              constraints.maxWidth >= 1200
                                              ? 4
                                              : constraints.maxWidth >= 900
                                              ? 3
                                              : 2;
                                          final cardWidth =
                                              (constraints.maxWidth -
                                                  48 -
                                                  16 * (columns - 1)) /
                                              columns;
                                          return GridView.builder(
                                            key: PageStorageKey(
                                              'cinemas-${area.key}-grid',
                                            ),
                                            padding: const EdgeInsets.fromLTRB(
                                              24,
                                              8,
                                              24,
                                              16,
                                            ),
                                            itemCount: cinemas.length,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: columns,
                                                  crossAxisSpacing: 16,
                                                  mainAxisSpacing: 16,
                                                  mainAxisExtent:
                                                      (cardWidth - 24) / 2.4 +
                                                      38 +
                                                      MediaQuery.textScalerOf(
                                                        context,
                                                      ).scale(102),
                                                ),
                                            itemBuilder: (context, index) =>
                                                CinemaCard(
                                                  key: ValueKey(
                                                    cinemas[index].id,
                                                  ),
                                                  cinema: cinemas[index],
                                                  isGrid: true,
                                                ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          '© contributeurs OpenStreetMap · ODbL',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.muted.copyWith(fontSize: 10),
                        ),
                      ),
                      if (ref
                          .read(cinemaServiceProvider)
                          .usingLocalCopyFor(area))
                        const CinemaSourceNotice(allowRetry: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
