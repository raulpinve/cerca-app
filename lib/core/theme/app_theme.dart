import 'package:flutter/material.dart';

import 'app_colors.dart';

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF7F1E8),
  fontFamily: 'Inter',
  extensions: const [
    AppColors.warm,
  ],
);
