import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color surface; // fondo de tarjetas, chips, nav bar
  final Color border; // líneas y bordes sutiles
  final Color indicator; // "píldora" detrás del ícono activo
  final Color selected; // ícono/texto activo (terracota)
  final Color unselected; // ícono/texto inactivo (arena)
  final Color badge; // punto/badge de notificación
  final Color textPrimary;
  final Color textSecondary;

  const AppColors({
    required this.surface,
    required this.border,
    required this.indicator,
    required this.selected,
    required this.unselected,
    required this.badge,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const warm = AppColors(
    surface: Color(0xFFFAF7F2), // antes FFFDF9 — menos amarillo, más "papel"
    border: Color(0xFFE8DFD1), // antes EFE6D8 — más neutro, menos dulce
    indicator: Color(0xFFEFDDCC), // antes F3E4D4 — un poco más terroso
    selected: Color(0xFFAD5A38), // antes B5673A — más profundo, menos naranja
    unselected: Color(
      0xFF9C9284,
    ), // antes B0A283 — gris-taupe, no arena amarilla
    badge: Color(0xFFDB6B52), // antes D9755C — coral más vivo, más contraste
    textPrimary: Color(0xFF322A22), // antes 3A3226 — carbón cálido, más sobrio
    textSecondary: Color(
      0xFF8F8375,
    ), // antes A0906F — gris cálido, menos amarillo
  );

  @override
  AppColors copyWith({
    Color? surface,
    Color? border,
    Color? indicator,
    Color? selected,
    Color? unselected,
    Color? badge,
    Color? textPrimary,
    Color? textSecondary,
  }) {
    return AppColors(
      surface: surface ?? this.surface,
      border: border ?? this.border,
      indicator: indicator ?? this.indicator,
      selected: selected ?? this.selected,
      unselected: unselected ?? this.unselected,
      badge: badge ?? this.badge,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      indicator: Color.lerp(indicator, other.indicator, t)!,
      selected: Color.lerp(selected, other.selected, t)!,
      unselected: Color.lerp(unselected, other.unselected, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
