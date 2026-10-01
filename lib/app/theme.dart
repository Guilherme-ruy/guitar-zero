import 'package:flutter/material.dart';

/// Paleta do Guitar Zero. Centralizada para facilitar a evolução da
/// identidade visual.
abstract final class GzColors {
  static const background = Color(0xFF0B0C0F);
  static const surface = Color(0xFF16181D);
  static const line = Color(0xFF2A2D35);
  static const textPrimary = Color(0xFFF4F4F6);
  static const textSecondary = Color(0xFF8B909C);

  /// Cor de "fora de afinação".
  static const off = Color(0xFFFF8A3D);

  /// Cor de "afinado" — o zero.
  static const zero = Color(0xFF5BE5A9);

  /// Interpola entre [off] e [zero] conforme a proximidade de 0 cents.
  static Color forCents(double cents, {double range = 25}) {
    final t = (cents.abs() / range).clamp(0.0, 1.0);
    return Color.lerp(zero, off, t)!;
  }
}

abstract final class GzDurations {
  /// Interpolação visual entre leituras consecutivas.
  static const reading = Duration(milliseconds: 140);

  /// Transições de estado (destaque de corda, afinado).
  static const state = Duration(milliseconds: 260);
}

ThemeData buildGzTheme() {
  const tabular = [FontFeature.tabularFigures()];
  final base = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: GzColors.background,
    colorScheme: const ColorScheme.dark(
      surface: GzColors.surface,
      primary: GzColors.zero,
      secondary: GzColors.off,
      onSurface: GzColors.textPrimary,
    ),
    splashFactory: NoSplash.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: GzColors.textPrimary,
          displayColor: GzColors.textPrimary,
        )
        .copyWith(
          displayLarge: const TextStyle(
            fontSize: 96,
            fontWeight: FontWeight.w300,
            height: 1,
            letterSpacing: -2,
            fontFeatures: tabular,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            fontFeatures: tabular,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: GzColors.textSecondary,
          ),
        ),
  );
}
