// lib/core/config/stripe_config.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeConfig {
  // Clés Stripe 
  static const _publishableKeyTest = 'pk_test_51RZrcGFP5XewaRLGQGBWAbwzQA0lmiMChZnpIIes8XmjWaViRJvYtXAqCbQdm9UTAxFWyUnMLgEEx1CszjNr9HPq001jiS1UoG';
  static const _publishableKeyLive = 'pk_live_51...';

  static const _merchantIdentifier = 'merchant.com.votreapp.onlyflick';

  // Initialisation de Stripe
  static Future<void> initialize() async {
    try {
      print('[Stripe] Initialisation...');
      Stripe.publishableKey = _getPublishableKey();
      Stripe.merchantIdentifier = _merchantIdentifier;
      print('[Stripe] Initialisation réussie (${getCurrentEnvironment()})');
    } catch (e) {
      print('[Stripe] Erreur d\'initialisation: $e');
      rethrow;
    }
  }

  // Retourne la bonne clé selon l'environnement
  static String _getPublishableKey() {
    final key = kReleaseMode ? _publishableKeyLive : _publishableKeyTest;

    if ((kReleaseMode && !key.startsWith('pk_live_')) ||
        (!kReleaseMode && !key.startsWith('pk_test_'))) {
      throw Exception('Clé Stripe invalide pour l\'environnement actuel');
    }

    return key;
  }

  // Vérifie si Stripe est bien configuré
  static bool isConfigured() {
    final key = Stripe.publishableKey;
    return key.isNotEmpty &&
        (key.startsWith('pk_test_') || key.startsWith('pk_live_'));
  }

  // Indique l'environnement courant
  static String getCurrentEnvironment() =>
      kReleaseMode ? 'production' : 'test';

  // Vérifie la disponibilité d'Apple Pay
  static Future<bool> isApplePayAvailable() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        return await Stripe.instance.isPlatformPaySupported();
      } catch (e) {
        print('[Stripe] Erreur Apple Pay: $e');
      }
    }
    return false;
  }

  // Vérifie la disponibilité de Google Pay
  static Future<bool> isGooglePayAvailable() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await Stripe.instance.isPlatformPaySupported(
          googlePay: IsGooglePaySupportedParams(
            testEnv: !kReleaseMode,
          ),
        );
      } catch (e) {
        print('[Stripe] Erreur Google Pay: $e');
      }
    }
    return false;
  }

  static ThemeData getStripeTheme(BuildContext context) {
    final baseColor = Theme.of(context).primaryColor;

    return ThemeData(
      primarySwatch: Colors.blue,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: Theme.of(context).brightness,
      ),
    );
  }

  // Logs de debug
  static void enableDebugLogs() {
    if (!kReleaseMode) {
      print('[Stripe] Debug activé');
    }
  }

  // Gestion des messages d'erreur localisés
  static String getLocalizedErrorMessage(dynamic error) {
    final errorText = error.toString().toLowerCase();

    if (errorText.contains('user_cancel')) return 'Paiement annulé.';
    if (errorText.contains('insufficient_funds')) return 'Fonds insuffisants.';
    if (errorText.contains('card_declined')) return 'Carte refusée.';
    if (errorText.contains('expired_card')) return 'Carte expirée.';
    if (errorText.contains('invalid_cvc')) return 'CVC invalide.';
    if (errorText.contains('invalid_expiry')) return 'Date invalide.';
    if (errorText.contains('invalid_number')) return 'Numéro invalide.';
    if (errorText.contains('processing_error')) return 'Erreur de traitement.';
    if (errorText.contains('network')) return 'Erreur réseau.';

    return 'Erreur de paiement. Veuillez réessayer.';
  }

  // Constantes de configuration
  static const currency = 'EUR';
  static const country = 'FR';
  static const subscriptionPrice = 499; // en centimes

  // Formateur de prix
  static String formatPrice(int cents) {
    return '${(cents / 100).toStringAsFixed(2)} €';
  }
}

// Extension pratique sur BuildContext
extension StripeThemeExtension on BuildContext {
  ThemeData get stripeTheme => StripeConfig.getStripeTheme(this);
}