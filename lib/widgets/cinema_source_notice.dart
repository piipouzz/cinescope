import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../providers/cinema_provider.dart';

class CinemaSourceNotice extends ConsumerWidget {
  const CinemaSourceNotice({super.key, this.allowRetry = false});
  final bool allowRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(cinemaAreaProvider);
    final date = ref.read(cinemaServiceProvider).localCopyDateFor(area);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ShadButton.ghost(
          size: ShadButtonSize.sm,
          onPressed: () => showShadDialog(
            context: context,
            builder: (context) => ShadDialog(
              title: const Text('Provenance des données'),
              description: Text(
                'Copie locale OpenStreetMap${date == null ? '' : ' du $date'}. '
                'Seuls les cinémas enregistrés dans le rayon de cette zone sont affichés. '
                'Overpass est indisponible : ces informations ne sont pas actualisées en temps réel.',
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SelectableText(
                    '© contributeurs OpenStreetMap · ODbL\nhttps://www.openstreetmap.org/copyright',
                  ),
                  if (allowRetry) ...[
                    const SizedBox(height: 12),
                    const CinemaRetryButton(
                      label: 'Actualiser les données',
                      compact: true,
                    ),
                  ],
                ],
              ),
            ),
          ),
          child: const Icon(
            LucideIcons.info,
            size: 15,
            semanticLabel: 'Provenance et date des données',
          ),
        ),
      ],
    );
  }
}

class CinemaRetryButton extends ConsumerStatefulWidget {
  const CinemaRetryButton({
    super.key,
    this.label = 'Réessayer',
    this.compact = false,
  });
  final String label;
  final bool compact;
  @override
  ConsumerState<CinemaRetryButton> createState() => _CinemaRetryButtonState();
}

class _CinemaRetryButtonState extends ConsumerState<CinemaRetryButton> {
  Timer? _timer;
  void _countdown() {
    _timer?.cancel();
    if (ref.read(cinemaServiceProvider).retryDelay == Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (ref.read(cinemaServiceProvider).retryDelay == Duration.zero) {
        timer.cancel();
      }
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _countdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(cinemaServiceProvider);
    final area = ref.watch(cinemaAreaProvider);
    final loading = ref.watch(cinemasProvider).isLoading;
    final seconds = (service.retryDelay.inMilliseconds / 1000).ceil();
    if (loading && _timer?.isActive != true) _countdown();
    final label = loading
        ? 'Connexion…'
        : seconds > 0
        ? '${widget.label} ($seconds s)'
        : widget.label;
    void retry() {
      service.requestNetworkRetry(area);
      ref.invalidate(cinemasProvider);
      ref.invalidate(enrichedCinemasProvider);
      _countdown();
    }

    return ShadButton.outline(
      enabled: !loading && seconds == 0,
      size: widget.compact ? ShadButtonSize.sm : ShadButtonSize.regular,
      onPressed: retry,
      height: 0,
      child: Flexible(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: ShadTheme.of(context).textTheme.small
              .copyWith(fontSize: widget.compact ? 11 : 14),
        ),
      ),
    );
  }
}
