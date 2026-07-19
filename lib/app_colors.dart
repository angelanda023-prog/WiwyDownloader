import 'package:flutter/material.dart';

/// Paleta de la app, calcada del diseño de Wiwy Downloader.
class AppColors {
  // Fondos
  static const bg = Color(0xFF0A0A0F);
  static const card = Color(0xFF14141B);
  static const cardSoft = Color(0xFF1B1B24);
  static const border = Color(0xFF262631);
  static const inputBg = Color(0xFF101017);

  // Texto
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textMuted = Color(0xFF6B7280);

  // Naranja / marca
  static const orange = Color(0xFFFF7A00);
  static const orangeBright = Color(0xFFFF9100);
  static const red = Color(0xFFFF3D00);

  // Acentos de tarjetas
  static const purple = Color(0xFF8B5CF6);
  static const purpleDeep = Color(0xFF6D28D9);
  static const pink = Color(0xFFEC4899);
  static const pinkDeep = Color(0xFFBE185D);

  static const green = Color(0xFF22C55E);

  // Degradados
  static const orangeGradient = LinearGradient(
    colors: [orangeBright, red],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const purpleGradient = LinearGradient(
    colors: [purple, purpleDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const pinkGradient = LinearGradient(
    colors: [pink, pinkDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
