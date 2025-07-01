import 'dart:convert'; // ← Import manquant ajouté !
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../../core/services/api_service.dart';

/// Service pour gérer l'upload de médias via ImageKit
class MediaUploadService {
  final ApiService _apiService = ApiService();

  /// Upload d'une image vers ImageKit
  Future<MediaUploadResult> uploadImage(File imageFile) async {
    try {
      debugPrint('📤 Starting image upload: ${path.basename(imageFile.path)}');
      
      // Validation du fichier avant upload
      if (!imageFile.isValidImage) {
        return MediaUploadResult.failure('Format d\'image non supporté');
      }
      
      if (!await imageFile.isValidSize) {
        final sizeMB = await imageFile.sizeInMB;
        return MediaUploadResult.failure('Image trop volumineuse (${sizeMB.toStringAsFixed(1)}MB). Maximum 10MB.');
      }
      
      // Créer la requête multipart
      final uri = Uri.parse('${_apiService.baseUrl}/media/upload');
      final request = http.MultipartRequest('POST', uri);
      
      // Ajouter les headers d'authentification
      final token = _apiService.token;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Ajouter le fichier
      final multipartFile = await http.MultipartFile.fromPath(
        'file', // Nom du champ attendu par le backend
        imageFile.path,
        filename: path.basename(imageFile.path),
      );
      request.files.add(multipartFile);
      
      debugPrint('📤 Sending upload request...');
      
      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // debugPrint('📥 Upload response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        
        final result = MediaUploadResult.success(
          url: jsonData['url'] ?? '',
          fileId: jsonData['file_id'] ?? '',
        );
        
        // debugPrint('✅ Image uploaded successfully: ${result.url}');
        return result;
      } else {
        final errorMessage = _getErrorMessage(response);
        debugPrint('❌ Upload failed: $errorMessage');
        return MediaUploadResult.failure(errorMessage);
      }
      
    } catch (e) {
      debugPrint('❌ Upload error: $e');
      return MediaUploadResult.failure('Erreur lors de l\'upload: $e');
    }
  }

  /// Supprime un média par son file_id
  Future<bool> deleteMedia(String fileId) async {
    try {
      debugPrint('🗑️ Deleting media: $fileId');
      
      final response = await _apiService.delete('/media/$fileId');
      
      if (response.isSuccess) {
        debugPrint('✅ Media deleted successfully');
        return true;
      } else {
        debugPrint('❌ Failed to delete media: ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Delete media error: $e');
      return false;
    }
  }

  /// Extrait le message d'erreur de la réponse HTTP
  String _getErrorMessage(http.Response response) {
    try {
      final jsonData = jsonDecode(response.body);
      
      // Vérifier différents formats possibles de message d'erreur
      if (jsonData is Map<String, dynamic>) {
        // Format: {"error": "message"}
        if (jsonData.containsKey('error')) {
          return jsonData['error'].toString();
        }
        
        // Format: {"message": "message"}
        if (jsonData.containsKey('message')) {
          return jsonData['message'].toString();
        }
        
        // Format: {"detail": "message"}
        if (jsonData.containsKey('detail')) {
          return jsonData['detail'].toString();
        }
      }
      
      // Si aucun format reconnu, retourner le body s'il est court
      if (response.body.length < 200) {
        return response.body;
      }
      
    } catch (e) {
      debugPrint('🔍 Error parsing error message: $e');
    }
    
    // Fallback sur les codes de statut HTTP
    switch (response.statusCode) {
      case 400:
        return 'Fichier invalide - Vérifiez le format';
      case 401:
        return 'Non autorisé - Veuillez vous reconnecter';
      case 403:
        return 'Accès interdit';
      case 413:
        return 'Fichier trop volumineux (max 10MB)';
      case 415:
        return 'Type de fichier non supporté';
      case 429:
        return 'Trop de requêtes - Veuillez patienter';
      case 500:
        return 'Erreur serveur - Veuillez réessayer';
      default:
        return 'Erreur d\'upload (${response.statusCode})';
    }
  }
}

/// Résultat d'un upload de média
class MediaUploadResult {
  final bool isSuccess;
  final String? url;
  final String? fileId;
  final String? error;

  const MediaUploadResult._({
    required this.isSuccess,
    this.url,
    this.fileId,
    this.error,
  });

  factory MediaUploadResult.success({
    required String url,
    required String fileId,
  }) {
    return MediaUploadResult._(
      isSuccess: true,
      url: url,
      fileId: fileId,
    );
  }

  factory MediaUploadResult.failure(String error) {
    return MediaUploadResult._(
      isSuccess: false,
      error: error,
    );
  }

  bool get isFailure => !isSuccess;
}

/// Extensions pour la validation des fichiers
extension MediaValidation on File {
  /// Vérifie si le fichier est une image valide
  bool get isValidImage {
    final extension = path.extension(this.path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif'].contains(extension);
  }

  /// Vérifie la taille du fichier (max 10MB comme configuré dans AppConfig)
  Future<bool> get isValidSize async {
    try {
      final bytes = await length();
      const maxSizeBytes = 10 * 1024 * 1024; // 10MB
      return bytes <= maxSizeBytes;
    } catch (e) {
      return false;
    }
  }

  /// Retourne la taille du fichier en MB
  Future<double> get sizeInMB async {
    try {
      final bytes = await length();
      return bytes / (1024 * 1024);
    } catch (e) {
      return 0;
    }
  }
}