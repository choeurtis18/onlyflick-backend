enum AppEnvironment {
  dev,
  prod,
}

class AppConfig {
  static const AppEnvironment current = AppEnvironment.dev;

  static String get baseUrl {
    switch (current) {
      case AppEnvironment.prod:
        return 'https://api.onlyflick.io'; // URL de prod
      case AppEnvironment.dev:
      default:
        return 'http://10.0.2.2:8080'; // Backend local pour Android emulator
    }
  }

  static String get wsBaseUrl {
    switch (current) {
      case AppEnvironment.prod:
        return 'wss://api.onlyflick.io/ws'; // WebSocket sécurisé en prod
      case AppEnvironment.dev:
      default:
        return 'ws://10.0.2.2:8080/ws'; // WebSocket local
    }
  }

  static bool get isProduction => current == AppEnvironment.prod;
}
