import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service pour tester la connexion à l'API
class ApiHealthService {
  static final ApiHealthService _instance = ApiHealthService._internal();
  factory ApiHealthService() => _instance;
  ApiHealthService._internal();

  /// Teste la connexion à l'API de production
  Future<ApiHealthResult> testConnection() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Test de l'endpoint health
      final healthUrl = AppConfig.healthCheckUrl;
      print('🔍 Testing connection to: $healthUrl');
      
      final response = await http.get(
        Uri.parse(healthUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(AppConfig.connectTimeout);

      stopwatch.stop();
      
      return ApiHealthResult(
        success: response.statusCode == 200,
        statusCode: response.statusCode,
        responseTime: stopwatch.elapsedMilliseconds,
        message: _parseHealthResponse(response),
        environment: AppConfig.currentEnvironment.displayName,
        apiUrl: AppConfig.baseUrl,
      );
      
    } on SocketException catch (e) {
      stopwatch.stop();
      return ApiHealthResult(
        success: false,
        statusCode: 0,
        responseTime: stopwatch.elapsedMilliseconds,
        message: 'Erreur de connexion réseau: ${e.message}',
        environment: AppConfig.currentEnvironment.displayName,
        apiUrl: AppConfig.baseUrl,
        error: 'NETWORK_ERROR',
      );
    } on HttpException catch (e) {
      stopwatch.stop();
      return ApiHealthResult(
        success: false,
        statusCode: 0,
        responseTime: stopwatch.elapsedMilliseconds,
        message: 'Erreur HTTP: ${e.message}',
        environment: AppConfig.currentEnvironment.displayName,
        apiUrl: AppConfig.baseUrl,
        error: 'HTTP_ERROR',
      );
    } catch (e) {
      stopwatch.stop();
      return ApiHealthResult(
        success: false,
        statusCode: 0,
        responseTime: stopwatch.elapsedMilliseconds,
        message: 'Erreur inattendue: $e',
        environment: AppConfig.currentEnvironment.displayName,
        apiUrl: AppConfig.baseUrl,
        error: 'UNKNOWN_ERROR',
      );
    }
  }

  /// Parse la réponse de l'endpoint health
  String _parseHealthResponse(http.Response response) {
    try {
      if (response.body.isNotEmpty) {
        final data = json.decode(response.body);
        return data['status'] ?? 'API accessible';
      }
      return 'API accessible (${response.statusCode})';
    } catch (e) {
      return 'API accessible mais réponse non-JSON (${response.statusCode})';
    }
  }

  /// Teste plusieurs endpoints essentiels
  Future<List<EndpointTestResult>> testEssentialEndpoints() async {
    final endpoints = [
      '/health',
      '/login',
      '/register',
      '/posts/all',
    ];

    final results = <EndpointTestResult>[];
    
    for (final endpoint in endpoints) {
      final result = await _testSingleEndpoint(endpoint);
      results.add(result);
    }
    
    return results;
  }

  /// Teste un endpoint spécifique
  Future<EndpointTestResult> _testSingleEndpoint(String endpoint) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final url = AppConfig.getFullUrl(endpoint);
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      stopwatch.stop();
      
      return EndpointTestResult(
        endpoint: endpoint,
        url: url,
        success: response.statusCode < 500, // Accepter 4xx mais pas 5xx
        statusCode: response.statusCode,
        responseTime: stopwatch.elapsedMilliseconds,
        message: _getStatusMessage(response.statusCode),
      );
      
    } catch (e) {
      stopwatch.stop();
      return EndpointTestResult(
        endpoint: endpoint,
        url: AppConfig.getFullUrl(endpoint),
        success: false,
        statusCode: 0,
        responseTime: stopwatch.elapsedMilliseconds,
        message: 'Erreur: $e',
      );
    }
  }

  /// Retourne un message selon le code de statut
  String _getStatusMessage(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 401:
        return 'Non autorisé (normal pour certains endpoints)';
      case 404:
        return 'Endpoint non trouvé';
      case 405:
        return 'Méthode non autorisée (normal pour POST endpoints)';
      case 500:
        return 'Erreur serveur interne';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service indisponible';
      default:
        return 'Status: $statusCode';
    }
  }
}

/// Résultat du test de santé de l'API
class ApiHealthResult {
  final bool success;
  final int statusCode;
  final int responseTime;
  final String message;
  final String environment;
  final String apiUrl;
  final String? error;

  ApiHealthResult({
    required this.success,
    required this.statusCode,
    required this.responseTime,
    required this.message,
    required this.environment,
    required this.apiUrl,
    this.error,
  });

  /// Affiche le résultat dans la console
  void printResult() {
    print('=== API Health Check ===');
    print('🌍 Environment: $environment');
    print('🔗 URL: $apiUrl');
    print('✅ Success: ${success ? 'YES' : 'NO'}');
    print('📊 Status Code: $statusCode');
    print('⏱️ Response Time: ${responseTime}ms');
    print('💬 Message: $message');
    if (error != null) {
      print('❌ Error: $error');
    }
    print('=======================');
  }

  /// Convertit en Map pour debug
  Map<String, dynamic> toMap() => {
    'success': success,
    'statusCode': statusCode,
    'responseTime': responseTime,
    'message': message,
    'environment': environment,
    'apiUrl': apiUrl,
    'error': error,
  };
}

/// Résultat du test d'un endpoint spécifique
class EndpointTestResult {
  final String endpoint;
  final String url;
  final bool success;
  final int statusCode;
  final int responseTime;
  final String message;

  EndpointTestResult({
    required this.endpoint,
    required this.url,
    required this.success,
    required this.statusCode,
    required this.responseTime,
    required this.message,
  });

  /// Affiche le résultat dans la console
  void printResult() {
    final icon = success ? '✅' : '❌';
    print('$icon $endpoint ($statusCode) - ${responseTime}ms - $message');
  }
}