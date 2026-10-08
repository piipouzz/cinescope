import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  static final light = ShadThemeData(
    brightness: Brightness.light,
    colorScheme: const ShadVioletColorScheme.light(),
  );

  static final dark = ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadVioletColorScheme.dark(),
  );
}
