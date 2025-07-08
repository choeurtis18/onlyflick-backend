// lib/core/services/post_creation_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../services/api_service.dart';
import '../models/post_models.dart';

/// Service pour la création de posts avec support des tags
class PostCreationService {
  final ApiService _apiService = ApiService();

  /// Crée un nouveau post avec upload d'image et tags
  Future<PostCreationResult> createPost({
    required String title,
    required String description,
    required File imageFile,
    required PostVisibility visibility,
    List<String> tags = const [], // ✅ Nouveau paramètre tags
  }) async {
    try {
      debugPrint('📝 Creating post: $title with tags: $tags');
      
      // Validation du fichier
      if (!imageFile.isValidImage) {
        return PostCreationResult.failure('Format d\'image non supporté');
      }
      
      if (!await imageFile.isValidSize) {
        final sizeMB = await imageFile.sizeInMB;
        return PostCreationResult.failure('Image trop volumineuse (${sizeMB.toStringAsFixed(1)}MB). Maximum 10MB.');
      }
      
      // Préparer les champs et fichiers
      final fields = {
        'title': title,
        'description': description,
        'visibility': visibility.value,
        'tags': jsonEncode(tags), // ✅ Ajouter les tags en JSON
      };
      
      final files = {
        'media': imageFile, // Nom du champ attendu par le backend
      };
      
      debugPrint('📤 Sending post creation request with ${tags.length} tags...');
      
      // Utiliser la méthode multipart de l'ApiService
      final response = await _apiService.postMultipart<Post>(
        '/posts',
        fields: fields,
        files: files,
        fromJson: (json) => Post.fromJson(json),
      );
      
      if (response.isSuccess && response.data != null) {
        debugPrint('✅ Post created successfully: ${response.data!.id} with tags: ${response.data!.tags}');
        return PostCreationResult.success(response.data!);
      } else {
        debugPrint('❌ Post creation failed: ${response.error}');
        return PostCreationResult.failure(response.error ?? 'Erreur lors de la création du post');
      }
      
    } catch (e) {
      debugPrint('❌ Post creation error: $e');
      return PostCreationResult.failure('Erreur lors de la création: $e');
    }
  }

  /// Met à jour un post existant avec support des tags
  Future<PostCreationResult> updatePost({
    required int postId,
    required String title,
    required String description,
    required PostVisibility visibility,
    List<String> tags = const [], // ✅ Nouveau paramètre tags
    File? newImageFile,
  }) async {
    try {
      debugPrint('📝 Updating post: $postId with tags: $tags');
      
      // Si on a une nouvelle image, valider le fichier
      if (newImageFile != null) {
        if (!newImageFile.isValidImage) {
          return PostCreationResult.failure('Format d\'image non supporté');
        }
        
        if (!await newImageFile.isValidSize) {
          final sizeMB = await newImageFile.sizeInMB;
          return PostCreationResult.failure('Image trop volumineuse (${sizeMB.toStringAsFixed(1)}MB). Maximum 10MB.');
        }
      }
      
      // Créer la requête multipart
      final uri = Uri.parse('${_apiService.baseUrl}/posts/$postId');
      final request = http.MultipartRequest('PATCH', uri);
      
      // Ajouter les headers d'authentification
      final token = _apiService.token;
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      // Ajouter les champs du formulaire
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['visibility'] = visibility.value;
      request.fields['tags'] = jsonEncode(tags); // ✅ Ajouter les tags en JSON
      
      // Ajouter le nouveau fichier média si fourni
      if (newImageFile != null) {
        final multipartFile = await http.MultipartFile.fromPath(
          'media',
          newImageFile.path,
          filename: path.basename(newImageFile.path),
        );
        request.files.add(multipartFile);
      }
      
      debugPrint('📤 Sending post update request with ${tags.length} tags...');
      
      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('📥 Post update response ${response.statusCode}: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final post = Post.fromJson(jsonData);
        
        debugPrint('✅ Post updated successfully: ${post.id} with tags: ${post.tags}');
        return PostCreationResult.success(post);
      } else {
        final errorMessage = _getErrorMessage(response);
        debugPrint('❌ Post update failed: $errorMessage');
        return PostCreationResult.failure(errorMessage);
      }
      
    } catch (e) {
      debugPrint('❌ Post update error: $e');
      return PostCreationResult.failure('Erreur lors de la mise à jour: $e');
    }
  }

  /// Supprime un post
  Future<bool> deletePost(int postId) async {
    try {
      debugPrint('🗑️ Deleting post: $postId');
      
      final response = await _apiService.delete('/posts/$postId');
      
      if (response.isSuccess) {
        debugPrint('✅ Post deleted successfully');
        return true;
      } else {
        debugPrint('❌ Failed to delete post: ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Delete post error: $e');
      return false;
    }
  }

  /// Récupère un post par son ID
  Future<PostCreationResult> getPost(int postId) async {
    try {
      debugPrint('📖 Fetching post: $postId');
      
      final response = await _apiService.get<Post>(
        '/posts/$postId',
        fromJson: (json) => Post.fromJson(json),
      );
      
      if (response.isSuccess && response.data != null) {
        debugPrint('✅ Post fetched successfully: ${response.data!.id} with tags: ${response.data!.tags}');
        return PostCreationResult.success(response.data!);
      } else {
        debugPrint('❌ Post fetch failed: ${response.error}');
        return PostCreationResult.failure(response.error ?? 'Post non trouvé');
      }
    } catch (e) {
      debugPrint('❌ Post fetch error: $e');
      return PostCreationResult.failure('Erreur lors de la récupération: $e');
    }
  }

  /// Valide un fichier image avant upload
  Future<String?> validateImageFile(File imageFile) async {
    // Vérifier l'extension
    if (!imageFile.isValidImage) {
      return 'Format d\'image non supporté. Utilisez JPG, PNG ou GIF.';
    }
    
    // Vérifier la taille
    if (!await imageFile.isValidSize) {
      final sizeMB = await imageFile.sizeInMB;
      return 'Image trop volumineuse (${sizeMB.toStringAsFixed(1)}MB). Maximum 10MB.';
    }
    
    // Vérifier que le fichier existe
    if (!await imageFile.exists()) {
      return 'Le fichier image n\'existe pas.';
    }
    
    return null; // Pas d'erreur
  }

  /// Valide les données du post avant envoi
  String? validatePostData({
    required String title,
    required String description,
    required List<String> tags,
    File? imageFile,
  }) {
    // Validation du titre
    if (title.trim().isEmpty) {
      return 'Le titre est requis.';
    }
    if (title.trim().length < 3) {
      return 'Le titre doit contenir au moins 3 caractères.';
    }
    if (title.length > 100) {
      return 'Le titre ne peut pas dépasser 100 caractères.';
    }
    
    // Validation de la description
    if (description.trim().isEmpty) {
      return 'La description est requise.';
    }
    if (description.trim().length < 10) {
      return 'La description doit contenir au moins 10 caractères.';
    }
    if (description.length > 500) {
      return 'La description ne peut pas dépasser 500 caractères.';
    }
    
    // Validation des tags
    if (tags.isEmpty) {
      return 'Au moins un tag est requis.';
    }
    if (tags.length > 5) {
      return 'Maximum 5 tags autorisés.';
    }
    
    // Validation des tags individuels
    for (final tag in tags) {
      if (tag.trim().isEmpty) {
        return 'Les tags ne peuvent pas être vides.';
      }
      if (tag.length > 20) {
        return 'Les tags ne peuvent pas dépasser 20 caractères.';
      }
    }
    
    return null; // Pas d'erreur
  }

  /// Prévisualise les données qui seront envoyées
  Map<String, dynamic> previewPostData({
    required String title,
    required String description,
    required PostVisibility visibility,
    required List<String> tags,
    File? imageFile,
  }) {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'visibility': visibility.value,
      'tags': tags,
      'image_info': imageFile != null
          ? {
              'filename': path.basename(imageFile.path),
              'size_bytes': imageFile.lengthSync(),
              'extension': path.extension(imageFile.path),
            }
          : null,
      'validation_status': validatePostData(
        title: title,
        description: description,
        tags: tags,
        imageFile: imageFile,
      ) ?? 'Valid',
    };
  }

  /// Extrait le message d'erreur d'une réponse HTTP
  String _getErrorMessage(http.Response response) {
    try {
      // Essayer de décoder le JSON pour récupérer le message d'erreur
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
        
        // Format: {"errors": [...]}
        if (jsonData.containsKey('errors') && jsonData['errors'] is List) {
          final errors = jsonData['errors'] as List;
          if (errors.isNotEmpty) {
            return errors.first.toString();
          }
        }
      }
      
      // Si aucun format reconnu, retourner le body complet s'il est court
      if (response.body.length < 200) {
        return response.body;
      }
      
    } catch (e) {
      debugPrint('🔍 Error parsing error message: $e');
    }
    
    // Fallback sur les codes de statut HTTP standards
    switch (response.statusCode) {
      case 400:
        return 'Requête invalide - Vérifiez les données envoyées';
      case 401:
        return 'Non autorisé - Veuillez vous reconnecter';
      case 403:
        return 'Accès interdit - Vous n\'avez pas les permissions nécessaires';
      case 404:
        return 'Post non trouvé';
      case 413:
        return 'Fichier trop volumineux';
      case 415:
        return 'Type de fichier non supporté';
      case 422:
        return 'Données invalides - Vérifiez le titre et la description';
      case 429:
        return 'Trop de requêtes - Veuillez patienter';
      case 500:
        return 'Erreur serveur - Veuillez réessayer plus tard';
      case 502:
        return 'Service temporairement indisponible';
      case 503:
        return 'Service en maintenance';
      default:
        return 'Erreur ${response.statusCode} - ${response.reasonPhrase ?? 'Erreur inconnue'}';
    }
  }
}