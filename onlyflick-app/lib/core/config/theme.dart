import 'package:flutter/material.dart';

final ThemeData appTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
  useMaterial3: true,
  // Utiliser la police Roboto locale au lieu de la charger depuis Google Fonts
  fontFamily: 'Roboto',
  // Configuration des variantes de texte
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontFamily: 'Roboto'),
    displayMedium: TextStyle(fontFamily: 'Roboto'),
    displaySmall: TextStyle(fontFamily: 'Roboto'),
    headlineLarge: TextStyle(fontFamily: 'Roboto'),
    headlineMedium: TextStyle(fontFamily: 'Roboto'),
    headlineSmall: TextStyle(fontFamily: 'Roboto'),
    titleLarge: TextStyle(fontFamily: 'Roboto'),
    titleMedium: TextStyle(fontFamily: 'Roboto'),
    titleSmall: TextStyle(fontFamily: 'Roboto'),
    bodyLarge: TextStyle(fontFamily: 'Roboto'),
    bodyMedium: TextStyle(fontFamily: 'Roboto'),
    bodySmall: TextStyle(fontFamily: 'Roboto'),
    labelLarge: TextStyle(fontFamily: 'Roboto'),
    labelMedium: TextStyle(fontFamily: 'Roboto'),
    labelSmall: TextStyle(fontFamily: 'Roboto'),
  ),
);

// Classe utilitaire pour les polices personnalisées utilisées dans l'application
class AppFonts {
  // Empêcher l'instanciation
  AppFonts._();

  static const String roboto = 'Roboto';
  static const String pacifico = 'Pacifico';
  static const String inter = 'Inter';

  // Méthode d'aide pour TextStyle avec police Pacifico
  static TextStyle pacifico({
    double? size,
    Color? color,
    FontWeight? weight,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: 'Pacifico',
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      decoration: decoration,
    );
  }

  // Méthode d'aide pour TextStyle avec police Inter
  static TextStyle inter({
    double? size,
    Color? color,
    FontWeight? weight,
    double? height,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      color: color,
      fontWeight: weight,
      height: height,
      decoration: decoration,
    );
  }
}
