import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Niveaux de log
enum LogLevel {
  debug(0, 'DEBUG', '🔍'),
  info(1, 'INFO', 'ℹ️'),
  warning(2, 'WARN', '⚠️'),
  error(3, 'ERROR', '❌'),
  fatal(4, 'FATAL', '💀');

  const LogLevel(this.value, this.name, this.emoji);

  final int value;
  final String name;
  final String emoji;
}

/// Service de logging formaté pour l'application
class AppLogger {
  static LogLevel _currentLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  static const String _appName = 'OnlyFlick';

  /// Configure le niveau de log minimum
  static void setLevel(LogLevel level) {
    _currentLevel = level;
    _log(LogLevel.info, 'Logger', 'Log level set to ${level.name}');
  }

  /// Log de niveau DEBUG
  static void debug(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.debug, tag ?? 'DEBUG', message, error, stackTrace);
  }

  /// Log de niveau INFO
  static void info(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, tag ?? 'INFO', message, error, stackTrace);
  }

  /// Log de niveau WARNING
  static void warning(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, tag ?? 'WARNING', message, error, stackTrace);
  }

  /// Log de niveau ERROR
  static void error(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, tag ?? 'ERROR', message, error, stackTrace);
  }

  /// Log de niveau FATAL
  static void fatal(String message, [String? tag, Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.fatal, tag ?? 'FATAL', message, error, stackTrace);
  }

  /// Log spécifique pour les requêtes HTTP
  static void httpRequest(String method, String url, {Map<String, dynamic>? body}) {
    if (_shouldLog(LogLevel.debug)) {
      final message = '🌐 HTTP $method $url';
      _log(LogLevel.debug, 'HTTP', message);
      
      if (body != null && body.isNotEmpty) {
        _log(LogLevel.debug, 'HTTP', '📤 Request Body: $body');
      }
    }
  }

  /// Log spécifique pour les réponses HTTP
  static void httpResponse(int statusCode, String url, {dynamic body}) {
    final level = statusCode >= 400 ? LogLevel.error : LogLevel.debug;
    final emoji = statusCode >= 400 ? '❌' : '✅';
    final message = '$emoji HTTP $statusCode $url';
    
    _log(level, 'HTTP', message);
    
    if (body != null && _shouldLog(LogLevel.debug)) {
      _log(LogLevel.debug, 'HTTP', '📥 Response Body: $body');
    }
  }

  /// Log spécifique pour l'authentification
  static void auth(String message, {bool isError = false}) {
    final level = isError ? LogLevel.error : LogLevel.info;
    _log(level, 'AUTH', '🔐 $message');
  }

  /// Log spécifique pour la navigation
  static void navigation(String route, {Map<String, dynamic>? params}) {
    final message = '🧭 Navigating to: $route';
    _log(LogLevel.debug, 'NAV', message);
    
    if (params != null && params.isNotEmpty) {
      _log(LogLevel.debug, 'NAV', '📋 Params: $params');
    }
  }

  /// Log spécifique pour les performances
  static void performance(String operation, Duration duration) {
    final message = '⏱️ $operation took ${duration.inMilliseconds}ms';
    final level = duration.inMilliseconds > 1000 ? LogLevel.warning : LogLevel.debug;
    _log(level, 'PERF', message);
  }

  /// Méthode principale de logging
  static void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (!_shouldLog(level)) return;

    final timestamp = DateTime.now().toIso8601String();
    final formattedMessage = _formatMessage(level, tag, message, timestamp);

    // En mode debug, utilise developer.log pour de meilleurs outils de debug
    if (kDebugMode) {
      developer.log(
        formattedMessage,
        time: DateTime.now(),
        level: level.value,
        name: _appName,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      // En production, utilise print (peut être remplacé par un service externe)
      print(formattedMessage);
      
      if (error != null) {
        print('Error: $error');
      }
      
      if (stackTrace != null) {
        print('StackTrace: $stackTrace');
      }
    }

    // En cas d'erreur critique, on peut ajouter ici l'envoi vers un service externe
    // comme Crashlytics, Sentry, etc.
    if (level == LogLevel.error || level == LogLevel.fatal) {
      _sendToCrashlytics(level, tag, message, error, stackTrace);
    }
  }

  /// Vérifie si on doit logger pour ce niveau
  static bool _shouldLog(LogLevel level) {
    return level.value >= _currentLevel.value;
  }

  /// Formate le message de log
  static String _formatMessage(LogLevel level, String tag, String message, String timestamp) {
    return '${level.emoji} [$_appName] [$timestamp] [$tag] $message';
  }

  /// Envoie les erreurs critiques vers un service externe (placeholder)
  static void _sendToCrashlytics(
    LogLevel level,
    String tag,
    String message,
    Object? error,
    StackTrace? stackTrace,
  ) {
    // TODO: Implémenter l'envoi vers Firebase Crashlytics ou Sentry
    // Exemple:
    // FirebaseCrashlytics.instance.recordError(
    //   error ?? message,
    //   stackTrace,
    //   fatal: level == LogLevel.fatal,
    // );
  }
}

/// Extension pour logger facilement depuis n'importe quelle classe
extension LoggerExtension on Object {
  void logDebug(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.debug(message, runtimeType.toString(), error, stackTrace);
  }

  void logInfo(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.info(message, runtimeType.toString(), error, stackTrace);
  }

  void logWarning(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.warning(message, runtimeType.toString(), error, stackTrace);
  }

  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.error(message, runtimeType.toString(), error, stackTrace);
  }
}

/// Mixin pour ajouter facilement les capacités de logging à une classe
mixin LoggerMixin {
  void logDebug(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.debug(message, runtimeType.toString(), error, stackTrace);
  }

  void logInfo(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.info(message, runtimeType.toString(), error, stackTrace);
  }

  void logWarning(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.warning(message, runtimeType.toString(), error, stackTrace);
  }

  void logError(String message, [Object? error, StackTrace? stackTrace]) {
    AppLogger.error(message, runtimeType.toString(), error, stackTrace);
  }
}