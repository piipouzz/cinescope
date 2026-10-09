import 'package:flutter/foundation.dart';

void cinemaDiagnostic(String stage, String message) {
  if (const bool.fromEnvironment('CINEMA_DIAGNOSTICS')) {
    debugPrint('[CineScope/$stage] $message');
  }
}
