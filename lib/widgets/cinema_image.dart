import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../models/cinema.dart';
import '../services/cinema_diagnostics.dart';

class CinemaImage extends StatelessWidget {
  const CinemaImage({
    super.key,
    required this.cinema,
    this.aspectRatio = 16 / 9,
    this.fit = BoxFit.cover,
  });
  final Cinema cinema;
  final double aspectRatio;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    if (cinema.photo == null) {
      cinemaDiagnostic('photo', '${cinema.id}: no verified photo');
    }
    final placeholder = Semantics(
      label: 'Cinéma',
      image: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [theme.colorScheme.secondary, theme.colorScheme.muted],
          ),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.card.withValues(alpha: .65),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.clapperboard,
              size: 30,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: cinema.photo == null
            ? placeholder
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    cinema.photo!.url,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    headers:
                        const bool.fromEnvironment('dart.library.js_interop')
                        ? null
                        : const {
                            'User-Agent':
                                'CineScope/1.0 (educational cinema catalogue)',
                          },
                    fit: fit,
                    semanticLabel: 'Photo de ${cinema.name}',
                    errorBuilder: (context, error, stack) {
                      final message = error.toString().toLowerCase();
                      final failure = error is NetworkImageLoadException
                          ? 'HTTP ${error.statusCode}'
                          : message.contains('codec') ||
                                message.contains('decode') ||
                                message.contains('image data')
                          ? 'decode'
                          : 'network';
                      cinemaDiagnostic(
                        'photo',
                        '${cinema.id} ${cinema.photo!.url}: '
                            '$failure $error',
                      );
                      return placeholder;
                    },
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : placeholder,
                    frameBuilder: (context, child, frame, synchronouslyLoaded) {
                      if (frame != null) {
                        cinemaDiagnostic(
                          'photo',
                          '${cinema.id}: decoded frame $frame',
                        );
                      }
                      return child;
                    },
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Semantics(
                      button: true,
                      label: 'Crédits de la photo',
                      child: Material(
                        color: theme.colorScheme.card,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => showShadDialog<void>(
                            context: context,
                            builder: (context) => ShadDialog(
                              title: const Text('Crédits de la photo'),
                              child: SelectableText(
                                '${cinema.photo!.author} · ${cinema.photo!.license}\n'
                                '${cinema.photo!.credit}\n${cinema.photo!.sourceName}\n'
                                '${cinema.photo!.sourceUrl}\n${cinema.photo!.licenseUrl}'
                                '${fit == BoxFit.cover ? '\nVue recadrée pour la vignette.' : ''}',
                              ),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(LucideIcons.info, size: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
