import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
//  Import de la configuration centralisée
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  //  Utilisation d'AppConfig au lieu de la configuration en dur
  static String get _baseUrl => AppConfig.baseUrl;

  final http.Client _client = http.Client();
  String? _token;
  
  // : Gestion de l'ID utilisateur connecté
  int? _currentUserId;

  // Headers par défaut pour les requêtes JSON
  Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  // Headers pour les requêtes avec authentification uniquement
  Map<String, String> get _authOnlyHeaders => {
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// Getter public pour accéder à l'URL de base
  String get baseUrl => _baseUrl;

  /// : Getter pour obtenir l'ID de l'utilisateur connecté
  int? get currentUserId => _currentUserId;

  /// : Vérifie si un utilisateur est connecté
  bool get hasCurrentUser => _currentUserId != null;

  ///  Initialise le service avec debug info et test de connexion
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Charger le token
    _token = prefs.getString(AppConfig.tokenKey);
    
    // : Charger l'ID utilisateur
    _currentUserId = prefs.getInt('current_user_id');
    
    //  Affichage des informations de debug
    if (AppConfig.enableDetailedLogs) {
      debugPrint('🔐 ApiService initialized with token: ${_token != null}');
      debugPrint('🔐 Current user ID: $_currentUserId');
      debugPrint('🌍 Base URL: $_baseUrl');
      debugPrint('🌍 Environment: ${AppConfig.currentEnvironment.displayName}');
      debugPrint('📱 Platform: ${defaultTargetPlatform.name}');
    }
  }

  /// Met à jour le token d'authentification
  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(AppConfig.tokenKey, token);
      if (AppConfig.enableDetailedLogs) {
        debugPrint('🔐 Token saved: ${token.substring(0, 10)}...');
      }
    } else {
      await prefs.remove(AppConfig.tokenKey);
      if (AppConfig.enableDetailedLogs) {
        debugPrint('🔐 Token cleared');
      }
    }
  }

  /// : Met à jour l'ID de l'utilisateur connecté (appelé après login)
  Future<void> setCurrentUser(int userId) async {
    _currentUserId = userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_user_id', userId);
    if (AppConfig.enableDetailedLogs) {
      debugPrint('🔐 Current user ID saved: $userId');
    }
  }

  /// : Efface l'ID de l'utilisateur (appelé lors du logout)
  Future<void> clearCurrentUser() async {
    _currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    if (AppConfig.enableDetailedLogs) {
      debugPrint('🔐 Current user ID cleared');
    }
  }

  /// : Déconnexion complète (token + user)
  Future<void> logout() async {
    await setToken(null);
    await clearCurrentUser();
    debugPrint('🔐 Complete logout performed');
  }

  /// Récupère le token actuel
  String? get token => _token;

  /// Vérifie si un token est disponible
  bool get hasToken => _token != null;

  /// GET Request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _makeRequest<T>('GET', endpoint, queryParams: queryParams, fromJson: fromJson);
  }

  /// POST Request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Object? body,
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _makeRequest<T>('POST', endpoint, body: body, queryParams: queryParams, fromJson: fromJson);
  }

  /// PATCH Request
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    Object? body,
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _makeRequest<T>('PATCH', endpoint, body: body, queryParams: queryParams, fromJson: fromJson);
  }

  /// DELETE Request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    return _makeRequest<T>('DELETE', endpoint, queryParams: queryParams, fromJson: fromJson);
  }

  /// POST Request avec fichier multipart
  Future<ApiResponse<T>> postMultipart<T>(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, File>? files,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint, null);
      if (AppConfig.enableHttpLogs) {
        debugPrint('🌐 POST MULTIPART ${uri.toString()}');
        debugPrint('📤 Fields: $fields');
        if (files != null) debugPrint('📎 Files: ${files.keys.toList()}');
      }

      final request = http.MultipartRequest('POST', uri);
      
      // Ajouter les headers d'authentification
      request.headers.addAll(_authOnlyHeaders);
      
      // Ajouter les champs
      request.fields.addAll(fields);
      
      // Ajouter les fichiers
      if (files != null) {
        for (final entry in files.entries) {
          final file = entry.value;
          final multipartFile = await http.MultipartFile.fromPath(
            entry.key,
            file.path,
            filename: file.path.split('/').last,
          );
          request.files.add(multipartFile);
        }
      }
      
      // Envoyer la requête avec timeout configuré
      final streamedResponse = await request.send().timeout(
        AppConfig.apiTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      if (AppConfig.enableHttpLogs) {
        debugPrint('📥 Response ${response.statusCode}: ${response.body}');
      }
      return _handleResponse<T>(response, fromJson);
      
    } on SocketException {
      debugPrint('❌ No internet connection');
      return ApiResponse.error('Pas de connexion internet');
    } on HttpException {
      debugPrint('❌ HTTP error occurred');
      return ApiResponse.error('Erreur de communication avec le serveur');
    } on FormatException {
      debugPrint('❌ Bad response format');
      return ApiResponse.error('Format de réponse invalide');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return ApiResponse.error('Erreur lors de l\'upload: $e');
    }
  }

  /// PATCH Request avec fichier multipart
  Future<ApiResponse<T>> patchMultipart<T>(
    String endpoint, {
    required Map<String, String> fields,
    Map<String, File>? files,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint, null);
      if (AppConfig.enableHttpLogs) {
        debugPrint('🌐 PATCH MULTIPART ${uri.toString()}');
        debugPrint('📤 Fields: $fields');
        if (files != null) debugPrint('📎 Files: ${files.keys.toList()}');
      }

      final request = http.MultipartRequest('PATCH', uri);
      
      // Ajouter les headers d'authentification
      request.headers.addAll(_authOnlyHeaders);
      
      // Ajouter les champs
      request.fields.addAll(fields);
      
      // Ajouter les fichiers
      if (files != null) {
        for (final entry in files.entries) {
          final file = entry.value;
          final multipartFile = await http.MultipartFile.fromPath(
            entry.key,
            file.path,
            filename: file.path.split('/').last,
          );
          request.files.add(multipartFile);
        }
      }
      
      // Envoyer la requête avec timeout configuré
      final streamedResponse = await request.send().timeout(
        AppConfig.apiTimeout,
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      if (AppConfig.enableHttpLogs) {
        debugPrint('📥 Response ${response.statusCode}: ${response.body}');
      }
      return _handleResponse<T>(response, fromJson);
      
    } on SocketException {
      debugPrint('❌ No internet connection');
      return ApiResponse.error('Pas de connexion internet');
    } on HttpException {
      debugPrint('❌ HTTP error occurred');
      return ApiResponse.error('Erreur de communication avec le serveur');
    } on FormatException {
      debugPrint('❌ Bad response format');
      return ApiResponse.error('Format de réponse invalide');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return ApiResponse.error('Erreur lors de la mise à jour: $e');
    }
  }

  ///  Méthode privée pour effectuer les requêtes HTTP standard avec timeouts configurés
  Future<ApiResponse<T>> _makeRequest<T>(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      
      if (AppConfig.enableHttpLogs) {
        debugPrint('🌐 $method ${uri.toString()}');
        if (body != null) debugPrint('📤 Body: ${jsonEncode(body)}');
      }

      final headers = _defaultHeaders;
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(
            AppConfig.connectTimeout,
          );
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(
            AppConfig.apiTimeout,
          );
          break;
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(
            AppConfig.apiTimeout,
          );
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(
            AppConfig.connectTimeout,
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (AppConfig.enableHttpLogs) {
        debugPrint('📥 Response ${response.statusCode}: ${response.body}');
      }
      return _handleResponse<T>(response, fromJson);

    } on SocketException {
      debugPrint('❌ No internet connection');
      return ApiResponse.error('Pas de connexion internet');
    } on HttpException {
      debugPrint('❌ HTTP error occurred');
      return ApiResponse.error('Erreur de communication avec le serveur');
    } on FormatException {
      debugPrint('❌ Bad response format');
      return ApiResponse.error('Format de réponse invalide');
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      //  Message d'erreur spécifique selon l'environnement
      if (AppConfig.isProduction) {
        return ApiResponse.error('Serveur temporairement indisponible. Veuillez réessayer.');
      } else {
        return ApiResponse.error('Serveur inaccessible. Vérifiez que votre backend Go est démarré.');
      }
    }
  }

  /// Construit l'URI avec les paramètres de requête
  Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final url = endpoint.startsWith('/') ? '$_baseUrl$endpoint' : '$_baseUrl/$endpoint';
    
    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(queryParameters: queryParams);
    }
    
    return Uri.parse(url);
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    final statusCode = response.statusCode;
    
    if (AppConfig.enableHttpLogs) {
      debugPrint('📡 Response status: $statusCode');
      debugPrint('📡 Response body: ${response.body}');
    }

    try {
      // Gestion des réponses vides (comme pour DELETE)
      if (response.body.isEmpty) {
        if (statusCode >= 200 && statusCode < 300) {
          return ApiResponse.success(null, statusCode);
        } else {
          return ApiResponse.error('Erreur serveur', statusCode);
        }
      }

      // Décoder le JSON
      final jsonData = jsonDecode(response.body);

      // Gestion des réponses de succès (2xx)
      if (statusCode >= 200 && statusCode < 300) {
        
        if (fromJson != null) {
          if (jsonData is Map<String, dynamic>) {
            // Cas normal : JSON object -> utiliser fromJson
            final data = fromJson(jsonData);
            return ApiResponse.success(data, statusCode);
          } else if (jsonData is List) {
            // : Cas spécifique pour les listes JSON
            // Dans ce cas, on retourne directement la liste sans parser
            if (AppConfig.enableHttpLogs) {
              debugPrint('📡 Response is a List, returning as-is');
            }
            return ApiResponse.success(jsonData as T, statusCode);
          } else {
            // Autres types de données
            return ApiResponse.success(jsonData as T, statusCode);
          }
        } else {
          // Pas de fromJson fourni, retour direct
          return ApiResponse.success(jsonData as T, statusCode);
        }
      } else {
        // Gestion des erreurs
        String message = 'Erreur inconnue';
        
        if (jsonData is Map<String, dynamic>) {
          message = jsonData['error'] ?? 
                   jsonData['message'] ?? 
                   'Erreur inconnue';
        } else if (jsonData is String) {
          message = jsonData;
        }
        
        if (AppConfig.enableHttpLogs) {
          debugPrint('❌ Server error message: $message');
        }
        
        // Gestion spécifique des erreurs 401
        if (statusCode == 401) {
          // Analyser le message pour déterminer le type d'erreur
          if (message.toLowerCase().contains('session') || 
              message.toLowerCase().contains('expir') ||
              message.toLowerCase().contains('token')) {
            // Session expirée - nettoyer la session locale
            _handleUnauthorized();
            return ApiResponse.error('Session expirée, veuillez vous reconnecter', statusCode);
          } else {
            // Erreur de credentials - NE PAS nettoyer la session
            // Utiliser le message exact du serveur
            return ApiResponse.error(message, statusCode);
          }
        }
        
        return ApiResponse.error(message, statusCode);
      }

    } catch (e) {
      if (AppConfig.enableHttpLogs) {
        debugPrint('❌ Error parsing JSON response: $e');
        debugPrint('❌ [ApiService] Failed to parse response: ${response.body}');
      }
      
      // Si on ne peut pas parser le JSON, utiliser le body brut
      final errorMessage = response.body.isNotEmpty ? response.body : 'Erreur de format de réponse';
      
      if (statusCode == 401) {
        if (errorMessage.toLowerCase().contains('session') || 
            errorMessage.toLowerCase().contains('expir') ||
            errorMessage.toLowerCase().contains('token')) {
          _handleUnauthorized();
          return ApiResponse.error('Session expirée, veuillez vous reconnecter', statusCode);
        } else {
          // Utiliser le message brut du serveur pour les erreurs de credentials
          return ApiResponse.error(errorMessage, statusCode);
        }
      }
      
      return ApiResponse.error(errorMessage, statusCode);
    }
  }

  /// Gère les erreurs d'authentification (401) 
  void _handleUnauthorized() {
    if (AppConfig.enableHttpLogs) {
      debugPrint('⚠️ Session expired - clearing local session');
    }
    logout();
  }

  Future<ApiResponse<Map<String, dynamic>>> searchPosts({
    String? query,
    List<String>? tags,
    String sortBy = 'recent',
    int limit = 20,
    int offset = 0,
  }) async {
    final params = {
      if (query != null && query.isNotEmpty) 'q': query,
      if (tags != null && tags.isNotEmpty) 'tags': tags.join(','),
      'sort_by': sortBy,
      'limit': '$limit',
      'offset': '$offset',
    };

    return get<Map<String, dynamic>>(
      '/search/posts',
      queryParams: params,
      fromJson: (json) => json,
    );
  }

  ///  Test de connectivité avec endpoint spécifique
  Future<bool> testConnection() async {
    try {
      final response = await get(AppConfig.healthCheckUrl.replaceFirst(_baseUrl, ''));
      return response.isSuccess;
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }

  /// : Vérifie si l'utilisateur est authentifié et valide
  bool get isAuthenticated => hasToken && hasCurrentUser;

  /// : Obtient les informations de session
  Map<String, dynamic> get sessionInfo => {
        'hasToken': hasToken,
        'hasUser': hasCurrentUser,
        'userId': currentUserId,
        'isAuthenticated': isAuthenticated,
        'environment': AppConfig.currentEnvironment.displayName,
        'baseUrl': _baseUrl,
      };

  /// Nettoyage des ressources
  void dispose() {
    _client.close();
  }
}

/// Classe générique pour wrapper les réponses de l'API
class ApiResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? error;
  final int? statusCode;

  const ApiResponse._({
    required this.isSuccess,
    this.data,
    this.error,
    this.statusCode,
  });

  /// Constructeur pour les réponses de succès
  factory ApiResponse.success(T? data, [int? statusCode]) {
    return ApiResponse._(
      isSuccess: true,
      data: data,
      statusCode: statusCode,
    );
  }

  /// Constructeur pour les réponses d'erreur
  factory ApiResponse.error(String error, [int? statusCode]) {
    return ApiResponse._(
      isSuccess: false,
      error: error,
      statusCode: statusCode,
    );
  }

  /// Vérifie si la réponse est un succès
  bool get isError => !isSuccess;

  /// Vérifie si c'est une erreur d'authentification
  bool get isAuthError => statusCode == 401;

  /// Vérifie si c'est une erreur de validation
  bool get isValidationError => statusCode == 400;

  /// Vérifie si c'est une erreur de permission
  bool get isPermissionError => statusCode == 403;

  /// Vérifie si c'est une erreur de ressource non trouvée
  bool get isNotFoundError => statusCode == 404;

  /// Vérifie si c'est une erreur serveur
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Vérifie si c'est une erreur réseau/client
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Message d'erreur formaté
  String get errorMessage {
    if (error != null) return error!;
    if (statusCode != null) {
      switch (statusCode!) {
        case 400:
          return 'Requête invalide';
        case 401:
          return 'Authentification requise';
        case 403:
          return 'Accès refusé';
        case 404:
          return 'Ressource non trouvée';
        case 500:
          return 'Erreur serveur';
        default:
          return 'Erreur HTTP $statusCode';
      }
    }
    return 'Erreur inconnue';
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'ApiResponse.success(data: $data, statusCode: $statusCode)';
    } else {
      return 'ApiResponse.error(error: $error, statusCode: $statusCode)';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ApiResponse<T> &&
        other.isSuccess == isSuccess &&
        other.data == data &&
        other.error == error &&
        other.statusCode == statusCode;
  }

  @override
  int get hashCode =>
      isSuccess.hashCode ^
      data.hashCode ^
      error.hashCode ^
      statusCode.hashCode;
}

/// Extensions utiles pour ApiResponse
extension ApiResponseExtensions<T> on ApiResponse<T> {
  /// Exécute une fonction si la réponse est un succès
  R? onSuccess<R>(R Function(T data) callback) {
    if (isSuccess && data != null) {
      return callback(data!);
    }
    return null;
  }

  /// Exécute une fonction si la réponse est une erreur
  R? onError<R>(R Function(String error, int? statusCode) callback) {
    if (isError && error != null) {
      return callback(error!, statusCode);
    }
    return null;
  }

  /// Transforme les données en un autre type
  ApiResponse<R> map<R>(R Function(T data) mapper) {
    if (isSuccess && data != null) {
      try {
        final mappedData = mapper(data!);
        return ApiResponse.success(mappedData, statusCode);
      } catch (e) {
        return ApiResponse.error('Error mapping data: $e', statusCode);
      }
    }
    return ApiResponse.error(error ?? 'No data to map', statusCode);
  }
}