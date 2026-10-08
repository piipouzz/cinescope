import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class AppTheme {
  static const background = Color(0xFFFFF5FA);
  static const pink = Color(0xFFFFD6E8);
  static const candy = Color(0xFFE86AA4);
  static const plum = Color(0xFF68405B);

  static final light = ShadThemeData(
    brightness: Brightness.light,
    radius: BorderRadius.circular(24),
    colorScheme: const ShadRoseColorScheme.light(
      background: background,
      foreground: plum,
      card: Colors.white,
      cardForeground: plum,
      popover: Colors.white,
      popoverForeground: plum,
      primary: candy,
      primaryForeground: Color(0xFF422038),
      secondary: pink,
      secondaryForeground: plum,
      muted: Color(0xFFFFEAF3),
      mutedForeground: Color(0xFF79536C),
      accent: pink,
      accentForeground: plum,
      destructive: Color(0xFFAC3868),
      destructiveForeground: Colors.white,
      border: Color(0xFFF4C8DC),
      input: pink,
      ring: candy,
      selection: pink,
    ),
    cardTheme: ShadCardTheme(
      radius: BorderRadius.circular(24),
      shadows: const [
        BoxShadow(
          color: Color(0x1268405B),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ],
    ),
  );
}
