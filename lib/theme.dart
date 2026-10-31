import 'package:flutter/material.dart';
import 'providers/app_state.dart';

const accentPalette = <int>[
  0xFF4F6BED, 0xFF0EA5A4, 0xFF16A34A, 0xFFF59E0B,
  0xFFEF4444, 0xFFEC4899, 0xFF8B5CF6, 0xFF64748B,
];

ThemeData buildTheme(Brightness b, AppState s, ColorScheme? dynamicScheme) {
  var scheme = (s.useDynamic && dynamicScheme != null)
      ? dynamicScheme
      : ColorScheme.fromSeed(seedColor: Color(s.accent), brightness: b);
  if (b == Brightness.dark && s.pureBlack) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF0E0E0E),
      surfaceContainer: const Color(0xFF131313),
      surfaceContainerHigh: const Color(0xFF191919),
      surfaceContainerHighest: const Color(0xFF202020),
    );
  }
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w600),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(elevation: 0, focusElevation: 0, hoverElevation: 0, highlightElevation: 0),
    dividerColor: scheme.outlineVariant.withValues(alpha: .4),
  );
}
