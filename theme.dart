import 'package:flutter/material.dart';

/// LOSSLESS design tokens: graphite surfaces, silver text, restrained blue.
class LColors {
  static const trueBlack = Color(0xFF000000);
  static const graphite = Color(0xFF0E0F11);
  static const charcoal = Color(0xFF17181B);
  static const border = Color(0xFF26282C);
  static const silver = Color(0xFFC9CDD2);
  static const silverDim = Color(0xFF7D838B);
  static const electric = Color(0xFF3D8BFF);
}

enum LThemeMode { amoled, dark, light }

ThemeData buildTheme(LThemeMode mode) {
  final light = mode == LThemeMode.light;
  final bg = switch (mode) {
    LThemeMode.amoled => LColors.trueBlack,
    LThemeMode.dark => LColors.graphite,
    LThemeMode.light => const Color(0xFFF4F5F7),
  };
  final fg = light ? const Color(0xFF14161A) : LColors.silver;
  final scheme = ColorScheme(
    brightness: light ? Brightness.light : Brightness.dark,
    primary: LColors.electric,
    onPrimary: Colors.white,
    secondary: LColors.silver,
    onSecondary: LColors.trueBlack,
    error: const Color(0xFFFF5C5C),
    onError: Colors.white,
    surface: light ? Colors.white : LColors.charcoal,
    onSurface: fg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    dividerColor: LColors.border,
    sliderTheme: const SliderThemeData(
      trackHeight: 2,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      activeTrackColor: LColors.electric,
      inactiveTrackColor: LColors.border,
    ),
  );
}
