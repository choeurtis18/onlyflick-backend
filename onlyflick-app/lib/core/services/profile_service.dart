import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../features/auth/models/auth_models.dart' as auth_models;  // ===== AJOUT ALIAS =====
import '../models/profile_models.dart'; 

/// Service pour les opérations de profil utilisateur
class ProfileService {
  final ApiService _apiService = ApiService();

  /// Récupération des statistiques du profil
  Future<ProfileStatsResult> getProfileStats() async {
    try {
      debugPrint('📊 Fetching profile stats');
      
      final response = await _apiService.get<ProfileStats>(
        '/profile/stats',
        fromJson: (json) => ProfileStats.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('📊 Profile stats fetched successfully');
        return ProfileStatsResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to fetch profile stats: ${response.error}');
        return ProfileStatsResult.failure(
          auth_models.AuthError.fromApiResponse(  // ===== CORRECTION ALIAS =====
            response.error ?? 'Erreur de récupération des statistiques',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Profile stats fetch error: $e');
      return ProfileStatsResult.failure(auth_models.AuthError.network());  // ===== CORRECTION ALIAS =====
    }
  }

  /// Récupération des posts de l'utilisateur - VERSION CORRIGÉE
  Future<UserPostsResult> getUserPosts({
    int page = 1,
    int limit = 20,
    String type = 'all', // 'all', 'public', 'subscriber'
  }) async {
    try {
      debugPrint('📝 Fetching user posts (page: $page, type: $type)');
      
      // ✅ CORRECTION: Utiliser dynamic pour éviter le problème de parsing
      final response = await _apiService.get<dynamic>(
        '/profile/posts?page=$page&limit=$limit&type=$type',
        fromJson: (json) => json, // Pas de parsing direct
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('📝 Raw response received, parsing posts...');
        
        // ✅ CORRECTION: Parsing manuel avec gestion d'erreur
        List<UserPost> posts = [];
        
        try {
          if (response.data is List) {
            final jsonList = response.data as List;
            
            for (var item in jsonList) {
              if (item is Map<String, dynamic>) {
                final post = UserPost.fromJson(item);
                posts.add(post);
                debugPrint('📝 ✅ Post parsed: ${post.id} - ${post.content}');
              }
            }
          } else {
            debugPrint('❌ Response data is not a List: ${response.data.runtimeType}');
            return UserPostsResult.failure(
              auth_models.AuthError.validation('response', 'Format de réponse invalide')  // ===== CORRECTION 2 ARGS =====
            );
          }
        } catch (parseError) {
          debugPrint('❌ Error parsing posts: $parseError');
          return UserPostsResult.failure(
            auth_models.AuthError.validation('parsing', 'Erreur de traitement des posts: $parseError')  // ===== CORRECTION 2 ARGS =====
          );
        }
        
        debugPrint('📝 User posts fetched successfully (${posts.length} posts)');
        return UserPostsResult.success(posts);
      } else {
        // debugPrint('❌ Failed to fetch user posts: ${response.error}');
        return UserPostsResult.failure(
          auth_models.AuthError.fromApiResponse(  // ===== CORRECTION ALIAS =====
            response.error ?? 'Erreur de récupération des posts',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ User posts fetch error: $e');
      return UserPostsResult.failure(auth_models.AuthError.network());  // ===== CORRECTION ALIAS =====
    }
  }

  /// Upload de l'avatar utilisateur
  Future<AvatarUploadResult> uploadAvatar(File imageFile) async {
    try {
      debugPrint('📤 Uploading avatar: ${imageFile.path}');
      
      // Validation basique du fichier
      if (!imageFile.existsSync()) {
        return AvatarUploadResult.failure(
          auth_models.AuthError.validation('file', 'Fichier image non trouvé')  // ===== CORRECTION 2 ARGS =====
        );
      }

      // Vérifier la taille (5MB max)
      final fileSizeInBytes = imageFile.lengthSync();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
      if (fileSizeInMB > 5) {
        return AvatarUploadResult.failure(
          auth_models.AuthError.validation('size', 'Image trop volumineuse (${fileSizeInMB.toStringAsFixed(1)}MB). Maximum 5MB.')  // ===== CORRECTION 2 ARGS =====
        );
      }

      // Vérifier l'extension
      final fileName = imageFile.path.toLowerCase();
      if (!fileName.endsWith('.jpg') && 
          !fileName.endsWith('.jpeg') && 
          !fileName.endsWith('.png') && 
          !fileName.endsWith('.gif')) {
        return AvatarUploadResult.failure(
          auth_models.AuthError.validation('format', 'Format non supporté. Utilisez JPG, PNG ou GIF.')  // ===== CORRECTION 2 ARGS =====
        );
      }

      final response = await _apiService.postMultipart<AvatarUploadResponse>(
        '/profile/avatar',
        fields: {}, // Pas de champs texte pour l'avatar
        files: {
          'avatar': imageFile, // Nom du champ attendu par le backend
        },
        fromJson: (json) => AvatarUploadResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('📤 Avatar uploaded successfully: ${response.data!.avatarUrl}');
        return AvatarUploadResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to upload avatar: ${response.error}');
        return AvatarUploadResult.failure(
          auth_models.AuthError.fromApiResponse(  // ===== CORRECTION ALIAS =====
            response.error ?? 'Erreur lors de l\'upload de l\'avatar',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Avatar upload error: $e');
      return AvatarUploadResult.failure(auth_models.AuthError.network());  // ===== CORRECTION ALIAS =====
    }
  }

  /// Mise à jour de la bio utilisateur
  Future<BioUpdateResult> updateBio(String bio) async {
    try {
      debugPrint('📝 Updating bio: ${bio.length} characters');
      
      // Validation de la bio
      if (bio.length > 500) {
        return BioUpdateResult.failure(
          auth_models.AuthError.validation('bio', 'Bio trop longue (${bio.length}/500 caractères)')  // ===== CORRECTION 2 ARGS =====
        );
      }

      final response = await _apiService.patch<Map<String, dynamic>>(
        '/profile/bio',
        body: {
          'bio': bio.trim(),
        },
        fromJson: (json) => json,
      );

      if (response.isSuccess) {
        debugPrint('📝 Bio updated successfully');
        return BioUpdateResult.success();
      } else {
        debugPrint('❌ Failed to update bio: ${response.error}');
        return BioUpdateResult.failure(
          auth_models.AuthError.fromApiResponse(  // ===== CORRECTION ALIAS =====
            response.error ?? 'Erreur lors de la mise à jour de la bio',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Bio update error: $e');
      return BioUpdateResult.failure(auth_models.AuthError.network());  // ===== CORRECTION ALIAS =====
    }
  }

  /// Vérification de la disponibilité d'un username
  Future<UsernameCheckResult> checkUsernameAvailability(String username) async {
    try {
      debugPrint('🔍 Checking username availability: $username');
      
      // Validation du username
      if (username.trim().isEmpty) {
        return UsernameCheckResult.failure(
          auth_models.AuthError.validation('username', 'Username ne peut pas être vide')  // ===== CORRECTION 2 ARGS =====
        );
      }

      if (username.length < 3 || username.length > 50) {
        return UsernameCheckResult.failure(
          auth_models.AuthError.validation('username', 'Username doit faire entre 3 et 50 caractères')  // ===== CORRECTION 2 ARGS =====
        );
      }

      final response = await _apiService.get<auth_models.UsernameCheckResponse>(  // ===== CORRECTION ALIAS =====
        '/profile/username/check?username=${Uri.encodeComponent(username.trim().toLowerCase())}',
        fromJson: (json) => auth_models.UsernameCheckResponse.fromJson(json),  // ===== CORRECTION ALIAS =====
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('🔍 Username check successful: ${response.data!.available}');
        return UsernameCheckResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to check username: ${response.error}');
        return UsernameCheckResult.failure(
          auth_models.AuthError.fromApiResponse(  // ===== CORRECTION ALIAS =====
            response.error ?? 'Erreur lors de la vérification du username',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Username check error: $e');
      return UsernameCheckResult.failure(auth_models.AuthError.network());  // ===== CORRECTION ALIAS =====
    }
  }
}

// ===== RÉSULTATS D'OPÉRATIONS =====

/// Résultat pour les statistiques profil
class ProfileStatsResult {
  final bool isSuccess;
  final ProfileStats? data;
  final auth_models.AuthError? error;  // ===== CORRECTION ALIAS =====

  const ProfileStatsResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory ProfileStatsResult.success(ProfileStats data) {
    return ProfileStatsResult._(isSuccess: true, data: data);
  }

  factory ProfileStatsResult.failure(auth_models.AuthError error) {  // ===== CORRECTION ALIAS =====
    return ProfileStatsResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'ProfileStatsResult.success($data)' 
      : 'ProfileStatsResult.failure($error)';
}

/// Résultat pour les posts utilisateur
class UserPostsResult {
  final bool isSuccess;
  final List<UserPost>? data;
  final auth_models.AuthError? error;  // ===== CORRECTION ALIAS =====

  const UserPostsResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory UserPostsResult.success(List<UserPost> data) {
    return UserPostsResult._(isSuccess: true, data: data);
  }

  factory UserPostsResult.failure(auth_models.AuthError error) {  // ===== CORRECTION ALIAS =====
    return UserPostsResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'UserPostsResult.success(${data?.length} posts)' 
      : 'UserPostsResult.failure($error)';
}

/// Résultat pour l'upload d'avatar
class AvatarUploadResult {
  final bool isSuccess;
  final AvatarUploadResponse? data;
  final auth_models.AuthError? error;  // ===== CORRECTION ALIAS =====

  const AvatarUploadResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory AvatarUploadResult.success(AvatarUploadResponse data) {
    return AvatarUploadResult._(isSuccess: true, data: data);
  }

  factory AvatarUploadResult.failure(auth_models.AuthError error) {  // ===== CORRECTION ALIAS =====
    return AvatarUploadResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'AvatarUploadResult.success(${data?.avatarUrl})' 
      : 'AvatarUploadResult.failure($error)';
}

/// Résultat pour la mise à jour de bio
class BioUpdateResult {
  final bool isSuccess;
  final auth_models.AuthError? error;  // ===== CORRECTION ALIAS =====

  const BioUpdateResult._({
    required this.isSuccess,
    this.error,
  });

  factory BioUpdateResult.success() {
    return const BioUpdateResult._(isSuccess: true);
  }

  factory BioUpdateResult.failure(auth_models.AuthError error) {  // ===== CORRECTION ALIAS =====
    return BioUpdateResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'BioUpdateResult.success()' 
      : 'BioUpdateResult.failure($error)';
}

/// Résultat pour la vérification de username
class UsernameCheckResult {
  final bool isSuccess;
  final auth_models.UsernameCheckResponse? data;  // ===== CORRECTION ALIAS =====
  final auth_models.AuthError? error;  // ===== CORRECTION ALIAS =====

  const UsernameCheckResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory UsernameCheckResult.success(auth_models.UsernameCheckResponse data) {  // ===== CORRECTION ALIAS =====
    return UsernameCheckResult._(isSuccess: true, data: data);
  }

  factory UsernameCheckResult.failure(auth_models.AuthError error) {  // ===== CORRECTION ALIAS =====
    return UsernameCheckResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'UsernameCheckResult.success(${data?.username}: ${data?.available})' 
      : 'UsernameCheckResult.failure($error)';
}