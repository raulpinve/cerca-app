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
    surface: Color(0xFFFAF7F2),
    border: Color(0xFFE8DFD1),
    indicator: Color(0xFFEFDDCC),
    selected: Color(0xFFAD5A38),
    unselected: Color(
      0xFF9C9284,
    ),
    badge: Color(0xFFDB6B52),
    textPrimary: Color(0xFF322A22),
    textSecondary: Color(
      0xFF8F8375,
    ),
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
