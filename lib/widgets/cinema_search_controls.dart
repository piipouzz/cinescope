import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/cinema_area.dart';
import '../providers/cinema_provider.dart';
import '../services/cinema_search_service.dart';

class CinemaSearchControls extends ConsumerStatefulWidget {
  const CinemaSearchControls({super.key});
  @override
  ConsumerState<CinemaSearchControls> createState() =>
      _CinemaSearchControlsState();
}

class _CinemaSearchControlsState extends ConsumerState<CinemaSearchControls> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _search({bool nearby = false}) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(cinemaSearchServiceProvider);
      CinemaArea? selected;
      if (nearby) {
        selected = await service.aroundMe();
      } else {
        final cities = await service.searchCities(_controller.text);
        if (!mounted) return;
        if (cities.isEmpty) {
          throw const CinemaSearchException(
            'Aucune ville trouvée. Vérifiez le nom saisi.',
          );
        }
        if (cities.length > 1) setState(() => _busy = false);
        selected = cities.length == 1
            ? cities.first
            : await showShadDialog<CinemaArea>(
                context: context,
                builder: (context) => ShadDialog(
                  title: const Text('Choisir une ville'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cities
                        .map(
                          (city) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: ShadButton.outline(
                              height: 0,
                              onPressed: () => Navigator.of(context).pop(city),
                              child: Flexible(
                                child: Text(
                                  city.label,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
      }
      if (mounted && selected != null) {
        ref.read(cinemaAreaProvider.notifier).select(selected);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is CinemaSearchException
              ? error.message
              : 'La recherche est indisponible. Réessayez.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final area = ref.watch(cinemaAreaProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ShadInput(
                key: const ValueKey('cinema-city-input'),
                controller: _controller,
                enabled: !_busy,
                placeholder: const Text(
                  'Ville…',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
              ),
            ),
            const SizedBox(width: 8),
            ShadButton(
              enabled: !_busy,
              onPressed: () => _search(),
              child: const Icon(
                LucideIcons.search,
                size: 18,
                semanticLabel: 'Rechercher la ville',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ShadButton.outline(
              enabled: !_busy,
              onPressed: () => _search(nearby: true),
              size: ShadButtonSize.sm,
              child: Flexible(
                child: Text(
                  'Autour de moi',
                  style: theme.textTheme.small.copyWith(fontSize: 12),
                ),
              ),
            ),
            if (_busy)
              const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                'Rayon de ${area.radiusLabel}',
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          area.label,
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: theme.textTheme.small.copyWith(
                color: theme.colorScheme.destructive,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
