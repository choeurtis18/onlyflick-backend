import 'package:flutter/foundation.dart';

/// Énumération des environnements disponibles
enum AppEnvironment {
  development('dev', 'Développement'),
  staging('staging', 'Recette'),
  production('prod', 'Production');

  const AppEnvironment(this.code, this.displayName);
  
  final String code;
  final String displayName;
}

/// Configuration centrale de l'application
class AppConfig {
  // Configuration de l'environnement
  static const AppEnvironment _currentEnvironment = kDebugMode 
      ? AppEnvironment.development 
      : AppEnvironment.production;

  /// Environnement actuel
  static AppEnvironment get currentEnvironment => _currentEnvironment;

  /// Indique si on est en mode debug
  static bool get isDebug => kDebugMode;

  /// Indique si on est en production
  static bool get isProduction => _currentEnvironment == AppEnvironment.production;

  /// Indique si on est en staging
  static bool get isStaging => _currentEnvironment == AppEnvironment.staging;

  // URLs de base pour l'API
  static String get baseUrl {
    switch (_currentEnvironment) {
      case AppEnvironment.production:
        return 'https://api.onlyflick.io';
      case AppEnvironment.staging:
        return 'https://staging-api.onlyflick.io';
      case AppEnvironment.development:
      default:
        // URL pour l'émulateur Android (10.0.2.2) ou iOS simulator (localhost)
        return defaultTargetPlatform == TargetPlatform.android
            ? 'http://10.0.2.2:8080'
            : 'http://localhost:8080';
    }
  }

  // URLs WebSocket
  static String get wsBaseUrl {
    switch (_currentEnvironment) {
      case AppEnvironment.production:
        return 'wss://api.onlyflick.io/ws';
      case AppEnvironment.staging:
        return 'wss://staging-api.onlyflick.io/ws';
      case AppEnvironment.development:
      default:
        return defaultTargetPlatform == TargetPlatform.android
            ? 'ws://10.0.2.2:8080/ws'
            : 'ws://localhost:8080/ws';
    }
  }

  // Configuration de l'API
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Configuration de l'authentification
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  // Configuration des logs
  static bool get enableDetailedLogs => isDebug;
  static bool get enableHttpLogs => isDebug;
  static bool get enablePerformanceLogs => isDebug;

  // Configuration de l'application
  static const String appName = 'OnlyFlick';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';

  // Configuration des médias
  static const int maxImageSizeMB = 10;
  static const int maxVideoSizeMB = 100;
  static const List<String> supportedImageFormats = ['jpg', 'jpeg', 'png', 'gif'];
  static const List<String> supportedVideoFormats = ['mp4', 'mov', 'avi'];

  // Configuration du cache
  static const Duration cacheExpiration = Duration(hours: 1);
  static const int maxCacheItems = 100;

  // Configuration des notifications
  static bool get enablePushNotifications => true;
  static bool get enableLocalNotifications => true;

  // URLs et endpoints spécifiques
  static String get healthCheckUrl => '$baseUrl/health';
  
  // Endpoints d'authentification
  static String get loginEndpoint => '/login';
  static String get registerEndpoint => '/register';
  static String get profileEndpoint => '/profile';
  static String get logoutEndpoint => '/logout';

  // Endpoints des posts
  static String get postsEndpoint => '/posts';
  static String get allPostsEndpoint => '/posts/all';
  static String postsFromCreatorEndpoint(int creatorId) => '/posts/from/$creatorId';
  static String subscriberOnlyPostsEndpoint(int creatorId) => '/posts/from/$creatorId/subscriber-only';

  // Endpoints des créateurs
  static String get creatorEndpoint => '/creator';
  static String get creatorPostsEndpoint => '/creator/posts';

  // Endpoints des abonnements
  static String get subscriptionsEndpoint => '/subscriptions';
  static String subscriptionPaymentEndpoint(int creatorId) => '/subscriptions/$creatorId/payment';
  static String unsubscribeEndpoint(int creatorId) => '/subscriptions/$creatorId';

  // Endpoints des commentaires
  static String get commentsEndpoint => '/comments';
  static String commentsForPostEndpoint(int postId) => '/comments/post/$postId';

  // Endpoints des likes
  static String postLikesEndpoint(int postId) => '/posts/$postId/likes';

  // Endpoints des médias
  static String get mediaUploadEndpoint => '/media/upload';
  static String mediaDeleteEndpoint(String fileId) => '/media/$fileId';

  // Endpoints des conversations
  static String get conversationsEndpoint => '/conversations';
  static String startConversationEndpoint(int receiverId) => '/conversations/$receiverId';
  static String conversationMessagesEndpoint(int conversationId) => '/conversations/$conversationId/messages';

  // Endpoints WebSocket
  static String wsMessagesEndpoint(int conversationId) => '/ws/messages/$conversationId';

  // Endpoints d'administration
  static String get adminDashboardEndpoint => '/admin/dashboard';
  static String get adminCreatorRequestsEndpoint => '/admin/creator-requests';
  static String approveCreatorRequestEndpoint(int requestId) => '/admin/creator-requests/$requestId/approve';
  static String rejectCreatorRequestEndpoint(int requestId) => '/admin/creator-requests/$requestId/reject';

  // Endpoints des signalements
  static String get reportsEndpoint => '/reports';
  static String get pendingReportsEndpoint => '/reports/pending';
  static String updateReportStatusEndpoint(int reportId) => '/reports/$reportId';

  /// Méthode pour obtenir l'URL complète d'un endpoint
  static String getFullUrl(String endpoint) {
    if (endpoint.startsWith('http')) {
      return endpoint;
    }
    return endpoint.startsWith('/') ? '$baseUrl$endpoint' : '$baseUrl/$endpoint';
  }

  /// Méthode pour obtenir l'URL WebSocket complète
  static String getFullWsUrl(String endpoint) {
    if (endpoint.startsWith('ws')) {
      return endpoint;
    }
    return endpoint.startsWith('/') ? '$wsBaseUrl$endpoint' : '$wsBaseUrl/$endpoint';
  }

  /// Configuration pour le debug
  static Map<String, dynamic> get debugInfo => {
    'environment': _currentEnvironment.displayName,
    'baseUrl': baseUrl,
    'wsBaseUrl': wsBaseUrl,
    'isDebug': isDebug,
    'isProduction': isProduction,
    'platform': defaultTargetPlatform.name,
    'appVersion': appVersion,
    'buildNumber': appBuildNumber,
  };

  /// Affiche les informations de configuration en mode debug
  static void printDebugInfo() {
    if (isDebug) {
      print('=== OnlyFlick Configuration ===');
      debugInfo.forEach((key, value) {
        print('$key: $value');
      });
      print('==============================');
    }
  }
}

/// Extension pour ajouter des méthodes utiles aux URLs
extension UrlExtensions on String {
  /// Combine cette URL avec l'URL de base si nécessaire
  String get asFullUrl => AppConfig.getFullUrl(this);
  
  /// Combine cette URL avec l'URL WebSocket de base si nécessaire
  String get asFullWsUrl => AppConfig.getFullWsUrl(this);
}