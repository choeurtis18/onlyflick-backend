import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Configuration selon votre backend Go et la plateforme
  static String get _baseUrl {
    if (kDebugMode) {
      // En développement, adapter selon la plateforme
      if (defaultTargetPlatform == TargetPlatform.android) {
        return 'http://10.0.2.2:8080';  // Android emulator
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        return 'http://localhost:8080';  // iOS simulator
      } else {
        return 'http://localhost:8080';  // Desktop/Web
      }
    } else {
      return 'https://api.onlyflick.io';  // Production
    }
  }

  final http.Client _client = http.Client();
  String? _token;

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

  /// Initialise le service avec le token stocké
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    debugPrint('🔐 ApiService initialized with token: ${_token != null}');
    debugPrint('🌍 Base URL: $_baseUrl');
  }

  /// Met à jour le token d'authentification
  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
      debugPrint('🔐 Token saved: ${token.substring(0, 10)}...');
    } else {
      await prefs.remove('auth_token');
      debugPrint('🔐 Token cleared');
    }
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
      debugPrint('🌐 POST MULTIPART ${uri.toString()}');
      debugPrint('📤 Fields: $fields');
      if (files != null) debugPrint('📎 Files: ${files.keys.toList()}');

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
      
      // Envoyer la requête
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📥 Response ${response.statusCode}: ${response.body}');
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
      debugPrint('🌐 PATCH MULTIPART ${uri.toString()}');
      debugPrint('📤 Fields: $fields');
      if (files != null) debugPrint('📎 Files: ${files.keys.toList()}');

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
      
      // Envoyer la requête
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📥 Response ${response.statusCode}: ${response.body}');
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

  /// Méthode privée pour effectuer les requêtes HTTP standard
  Future<ApiResponse<T>> _makeRequest<T>(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      
      debugPrint('🌐 $method ${uri.toString()}');
      if (body != null) debugPrint('📤 Body: ${jsonEncode(body)}');

      final headers = _defaultHeaders;
      late http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: headers).timeout(
            const Duration(seconds: 15),
          );
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(
            const Duration(seconds: 15),
          );
          break;
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(
            const Duration(seconds: 15),
          );
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: headers).timeout(
            const Duration(seconds: 15),
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      debugPrint('📥 Response ${response.statusCode}: ${response.body}');
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
      return ApiResponse.error('Serveur inaccessible. Vérifiez que votre backend Go est démarré.');
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

  /// Traite la réponse HTTP et la convertit en ApiResponse
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(Map<String, dynamic>)? fromJson,
  ) {
    final statusCode = response.statusCode;
    
    try {
      // Gestion des réponses vides (comme pour DELETE)
      if (response.body.isEmpty) {
        if (statusCode >= 200 && statusCode < 300) {
          return ApiResponse.success(null, statusCode);
        } else {
          return ApiResponse.error('Erreur serveur', statusCode);
        }
      }

      final jsonData = jsonDecode(response.body);

      // Gestion des réponses de succès (2xx)
      if (statusCode >= 200 && statusCode < 300) {
        if (fromJson != null && jsonData is Map<String, dynamic>) {
          final data = fromJson(jsonData);
          return ApiResponse.success(data, statusCode);
        } else {
          return ApiResponse.success(jsonData, statusCode);
        }
      }

      // Gestion des erreurs avec format du backend Go
      if (jsonData is Map<String, dynamic>) {
        final message = jsonData['message'] ?? jsonData['error'] ?? 'Erreur inconnue';
        
        // Gestion spécifique des erreurs d'authentification
        if (statusCode == 401) {
          _handleUnauthorized();
          return ApiResponse.error('Session expirée, veuillez vous reconnecter', statusCode);
        }
        
        return ApiResponse.error(message, statusCode);
      }

      return ApiResponse.error('Erreur de format de réponse', statusCode);

    } catch (e) {
      debugPrint('❌ Error parsing response: $e');
      return ApiResponse.error('Erreur de traitement de la réponse', statusCode);
    }
  }

  /// Gère les erreurs d'authentification (401)
  void _handleUnauthorized() {
    debugPrint('⚠️ Unauthorized access - clearing token');
    setToken(null);
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


  /// Test de connectivité avec le serveur
  Future<bool> testConnection() async {
    try {
      final response = await get('/health');
      return response.isSuccess;
    } catch (e) {
      debugPrint('❌ Connection test failed: $e');
      return false;
    }
  }

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