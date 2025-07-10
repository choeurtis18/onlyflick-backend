// lib/core/services/posts_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../models/post_models.dart';

/// Service pour la gestion complète des posts
class PostsService {
  final ApiService _apiService = ApiService();

  // RÉCUPÉRATION DES POSTS

  /// Récupère un post spécifique par son ID
  Future<PostResult> getPostById(int postId) async {
    try {
      debugPrint('🔍 [PostsService] Fetching post by ID: $postId');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        '/posts/$postId',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final post = Post.fromJson(response.data!);
        debugPrint('✅ [PostsService] Post $postId fetched successfully: "${post.title}"');
        return PostResult.success(post);
      } else {
        debugPrint('❌ [PostsService] Failed to fetch post $postId: ${response.error}');
        return PostResult.failure(response.error ?? 'Post introuvable');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching post $postId: $e');
      return PostResult.failure('Erreur lors de la récupération du post');
    }
  }

  /// Récupère tous les posts visibles pour l'utilisateur connecté
  Future<PostsResult> getAllPosts({int? limit, int? offset}) async {
    try {
      debugPrint('📱 [PostsService] Fetching all visible posts (limit: $limit, offset: $offset)');
      
      Map<String, String> queryParams = {};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();
      
      final response = await _apiService.get<dynamic>(
        '/posts/all',
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.isSuccess && response.data != null) {
        List<Post> posts = [];
        
        if (response.data is List) {
          final postsData = response.data as List;
          posts = postsData
              .map((json) => Post.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('posts')) {
            final postsData = responseMap['posts'] as List;
            posts = postsData
                .map((json) => Post.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
        
        debugPrint('✅ [PostsService] ${posts.length} posts fetched successfully');
        return PostsResult.success(posts);
      } else {
        debugPrint('❌ [PostsService] Failed to fetch posts: ${response.error}');
        return PostsResult.failure(response.error ?? 'Erreur de récupération des posts');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching posts: $e');
      return PostsResult.failure('Erreur lors de la récupération des posts');
    }
  }

  /// Récupère les posts recommandés avec pagination
  Future<PostsResult> getRecommendedPosts({
    int limit = 20,
    int offset = 0,
    List<String>? tags,
  }) async {
    try {
      debugPrint('🤖 [PostsService] Fetching recommended posts (limit: $limit, offset: $offset, tags: $tags)');

      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }

      final response = await _apiService.get<dynamic>(
        '/posts/recommended',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        List<Post> posts = [];
        
        // Vérifier le type de données reçues
        if (response.data is List) {
          // Si c'est directement une liste de posts
          final postsData = response.data as List;
          posts = postsData
              .map((json) => Post.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map<String, dynamic>) {
          // Si c'est wrappé dans un objet avec pagination
          final responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('posts')) {
            final postsData = responseMap['posts'] as List;
            posts = postsData
                .map((json) => Post.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }

        debugPrint('✅ [PostsService] ${posts.length} recommended posts fetched successfully');
        return PostsResult.success(posts);
      } else {
        debugPrint('❌ [PostsService] Failed to fetch recommended posts: ${response.error}');
        return PostsResult.failure(response.error ?? 'Erreur de récupération des posts recommandés');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching recommended posts: $e');
      return PostsResult.failure('Erreur lors de la récupération des posts recommandés');
    }
  }

  /// Récupère les posts d'un créateur spécifique avec pagination
  Future<PostsResult> getCreatorPosts(
    int creatorId, {
    bool subscriberOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('👤 [PostsService] Fetching posts from creator: $creatorId (subscriberOnly: $subscriberOnly)');
      
      String endpoint;
      if (subscriberOnly) {
        endpoint = '/posts/from/$creatorId/subscriber-only';
      } else {
        endpoint = '/posts/from/$creatorId';
      }

      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final response = await _apiService.get<dynamic>(
        endpoint,
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        List<Post> posts = [];
        
        // Vérifier le type de données reçues
        if (response.data is List) {
          final postsData = response.data as List;
          posts = postsData
              .map((json) => Post.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('posts')) {
            final postsData = responseMap['posts'] as List;
            posts = postsData
                .map((json) => Post.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
        
        debugPrint('✅ [PostsService] ${posts.length} posts from creator $creatorId fetched successfully');
        return PostsResult.success(posts);
      } else {
        debugPrint('❌ [PostsService] Failed to fetch creator posts: ${response.error}');
        return PostsResult.failure(response.error ?? 'Erreur de récupération des posts du créateur');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching creator posts: $e');
      return PostsResult.failure('Erreur lors de la récupération des posts du créateur');
    }
  }

  /// Récupère mes posts (pour l'utilisateur connecté)
  Future<PostsResult> getMyPosts({
    String? visibility, // 'public', 'subscriber', ou null pour tous
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('👤 [PostsService] Fetching my posts (visibility: $visibility)');
      
      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      if (visibility != null) {
        queryParams['visibility'] = visibility;
      }
      
      final response = await _apiService.get<dynamic>(
        '/posts/me',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        List<Post> posts = [];
        
        // Vérifier le type de données reçues
        if (response.data is List) {
          final postsData = response.data as List;
          posts = postsData
              .map((json) => Post.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('posts')) {
            final postsData = responseMap['posts'] as List;
            posts = postsData
                .map((json) => Post.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
        
        debugPrint('✅ [PostsService] ${posts.length} of my posts fetched successfully');
        return PostsResult.success(posts);
      } else {
        debugPrint('❌ [PostsService] Failed to fetch my posts: ${response.error}');
        return PostsResult.failure(response.error ?? 'Erreur de récupération de vos posts');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching my posts: $e');
      return PostsResult.failure('Erreur lors de la récupération de vos posts');
    }
  }

  // INTERACTIONS AVEC LES POSTS (LIKE/UNLIKE)

  /// Toggle like/unlike sur un post
  Future<LikeToggleResult> toggleLike(int postId) async {
    try {
      debugPrint('❤️ [PostsService] Toggling like for post: $postId');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        '/posts/$postId/likes',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final liked = response.data!['liked'] ?? false;
        final likesCount = response.data!['likes_count'] ?? 0;
        debugPrint('✅ [PostsService] Post $postId like toggled: $liked (total: $likesCount)');
        return LikeToggleResult.success(liked, likesCount);
      } else {
        debugPrint('❌ [PostsService] Failed to toggle like: ${response.error}');
        return LikeToggleResult.failure(response.error ?? 'Erreur lors du like');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception toggling like: $e');
      return LikeToggleResult.failure('Erreur lors du like');
    }
  }

  /// Récupère le statut de like et le nombre de likes d'un post
  Future<LikeStatusResult> getPostLikeStatus(int postId) async {
    try {
      debugPrint('📊 [PostsService] Fetching like status for post: $postId');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        '/posts/$postId/likes',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final likesCount = response.data!['likes_count'] ?? 0;
        final isLiked = response.data!['is_liked'] ?? false;
        debugPrint('✅ [PostsService] Post $postId: $likesCount likes, liked: $isLiked');
        return LikeStatusResult.success(likesCount, isLiked);
      } else {
        debugPrint('❌ [PostsService] Failed to fetch like status: ${response.error}');
        return LikeStatusResult.failure(response.error ?? 'Erreur de récupération du statut de like');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching like status: $e');
      return LikeStatusResult.failure('Erreur lors de la récupération du statut de like');
    }
  }

  // GESTION DES COMMENTAIRES

  /// Récupère les commentaires d'un post avec pagination
  Future<CommentsResult> getPostComments(
    int postId, {
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('💬 [PostsService] Fetching comments for post: $postId (limit: $limit, offset: $offset)');
      
      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      final response = await _apiService.get<dynamic>(
        '/comments/post/$postId',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        List<Comment> comments = [];
        
        // Vérifier le type de données reçues
        if (response.data is List) {
          // Si c'est directement une liste de commentaires
          final commentsData = response.data as List;
          comments = commentsData
              .map((json) => Comment.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map<String, dynamic>) {
          // Si c'est wrappé dans un objet avec pagination
          final responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('comments')) {
            final commentsData = responseMap['comments'] as List;
            comments = commentsData
                .map((json) => Comment.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
        
        debugPrint('✅ [PostsService] ${comments.length} comments fetched for post $postId');
        return CommentsResult.success(comments);
      } else {
        debugPrint('❌ [PostsService] Failed to fetch comments: ${response.error}');
        return CommentsResult.failure(response.error ?? 'Erreur de récupération des commentaires');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching comments: $e');
      return CommentsResult.failure('Erreur lors de la récupération des commentaires');
    }
  }

  /// Ajoute un commentaire à un post
  Future<CommentResult> addComment(int postId, String content) async {
    try {
      debugPrint('💬 [PostsService] Adding comment to post: $postId');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        '/comments',
        body: {
          'post_id': postId,
          'content': content.trim(),
        },
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final comment = Comment.fromJson(response.data!);
        debugPrint('✅ [PostsService] Comment added successfully to post $postId by ${comment.authorDisplayName}');
        return CommentResult.success(comment);
      } else {
        debugPrint('❌ [PostsService] Failed to add comment: ${response.error}');
        return CommentResult.failure(response.error ?? 'Erreur lors de l\'ajout du commentaire');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception adding comment: $e');
      return CommentResult.failure('Erreur lors de l\'ajout du commentaire');
    }
  }

  /// Supprime un commentaire
  Future<ServiceResult> deleteComment(int commentId) async {
    try {
      debugPrint('🗑️ [PostsService] Deleting comment: $commentId');
      
      final response = await _apiService.delete('/comments/$commentId');

      if (response.isSuccess) {
        debugPrint('✅ [PostsService] Comment $commentId deleted successfully');
        return ServiceResult.success('Commentaire supprimé');
      } else {
        debugPrint('❌ [PostsService] Failed to delete comment: ${response.error}');
        return ServiceResult.failure(response.error ?? 'Erreur lors de la suppression du commentaire');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception deleting comment: $e');
      return ServiceResult.failure('Erreur lors de la suppression du commentaire');
    }
  }

  // CRÉATION ET MODIFICATION DES POSTS

  /// Crée un nouveau post
  Future<PostResult> createPost({
    required String title,
    required String description,
    required String visibility, // 'public' ou 'subscriber'
    String? mediaPath,
    List<String>? tags,
  }) async {
    try {
      debugPrint('📝 [PostsService] Creating new post: "$title"');
      
      // Préparer les champs
      Map<String, String> fields = {
        'title': title.trim(),
        'description': description.trim(),
        'visibility': visibility,
      };
      
      if (tags != null && tags.isNotEmpty) {
        fields['tags'] = tags.join(',');
      }

      // Préparer les fichiers si nécessaire
      Map<String, File>? files;
      if (mediaPath != null) {
        files = {
          'media': File(mediaPath),
        };
      }

      final response = await _apiService.postMultipart<Map<String, dynamic>>(
        '/posts',
        fields: fields,
        files: files,
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final post = Post.fromJson(response.data!);
        debugPrint('✅ [PostsService] Post created successfully: ${post.id}');
        return PostResult.success(post);
      } else {
        debugPrint('❌ [PostsService] Failed to create post: ${response.error}');
        return PostResult.failure(response.error ?? 'Erreur lors de la création du post');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception creating post: $e');
      return PostResult.failure('Erreur lors de la création du post');
    }
  }

  /// Met à jour un post existant
  Future<PostResult> updatePost({
    required int postId,
    String? title,
    String? description,
    String? visibility,
    List<String>? tags,
    String? newMediaPath,
  }) async {
    try {
      debugPrint('✏️ [PostsService] Updating post: $postId');
      
      // Préparer les champs
      Map<String, String> fields = {};
      
      if (title != null) fields['title'] = title.trim();
      if (description != null) fields['description'] = description.trim();
      if (visibility != null) fields['visibility'] = visibility;
      if (tags != null) fields['tags'] = tags.join(',');

      // Préparer les fichiers si nécessaire
      Map<String, File>? files;
      if (newMediaPath != null) {
        files = {
          'media': File(newMediaPath),
        };
      }

      final response = await _apiService.patchMultipart<Map<String, dynamic>>(
        '/posts/$postId',
        fields: fields,
        files: files,
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final post = Post.fromJson(response.data!);
        debugPrint('✅ [PostsService] Post $postId updated successfully');
        return PostResult.success(post);
      } else {
        debugPrint('❌ [PostsService] Failed to update post: ${response.error}');
        return PostResult.failure(response.error ?? 'Erreur lors de la modification du post');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception updating post: $e');
      return PostResult.failure('Erreur lors de la modification du post');
    }
  }

  /// Supprime un post
  Future<ServiceResult> deletePost(int postId) async {
    try {
      debugPrint('🗑️ [PostsService] Deleting post: $postId');
      
      final response = await _apiService.delete('/posts/$postId');

      if (response.isSuccess) {
        debugPrint('✅ [PostsService] Post $postId deleted successfully');
        return ServiceResult.success('Post supprimé');
      } else {
        debugPrint('❌ [PostsService] Failed to delete post: ${response.error}');
        return ServiceResult.failure(response.error ?? 'Erreur lors de la suppression du post');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception deleting post: $e');
      return ServiceResult.failure('Erreur lors de la suppression du post');
    }
  }

  // SIGNALEMENT ET MODÉRATION

  /// Signale un post
  Future<ServiceResult> reportPost(int postId, String reason) async {
    try {
      debugPrint('🚩 [PostsService] Reporting post: $postId for reason: $reason');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        '/posts/$postId/report',
        body: {
          'reason': reason.trim(),
        },
        fromJson: (json) => json,
      );

      if (response.isSuccess) {
        debugPrint('✅ [PostsService] Post $postId reported successfully');
        return ServiceResult.success('Post signalé avec succès');
      } else {
        debugPrint('❌ [PostsService] Failed to report post: ${response.error}');
        return ServiceResult.failure(response.error ?? 'Erreur lors du signalement');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception reporting post: $e');
      return ServiceResult.failure('Erreur lors du signalement');
    }
  }

  // RECHERCHE ET FILTRAGE

  /// Recherche des posts par terme de recherche
  Future<PostsResult> searchPosts({
    required String query,
    List<String>? tags,
    String? visibility,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('🔍 [PostsService] Searching posts: "$query"');
      
      Map<String, String> queryParams = {
        'q': query.trim(),
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      if (tags != null && tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }
      
      if (visibility != null) {
        queryParams['visibility'] = visibility;
      }

      final response = await _apiService.get<dynamic>(
        '/posts/search',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        List<Post> posts = [];
        
        // Vérifier le type de données reçues
        if (response.data is List) {
          final postsData = response.data as List;
          posts = postsData
              .map((json) => Post.fromJson(json as Map<String, dynamic>))
              .toList();
        } else if (response.data is Map<String, dynamic>) {
          final responseMap = response.data as Map<String, dynamic>;
          if (responseMap.containsKey('posts')) {
            final postsData = responseMap['posts'] as List;
            posts = postsData
                .map((json) => Post.fromJson(json as Map<String, dynamic>))
                .toList();
          }
        }
        
        debugPrint('✅ [PostsService] ${posts.length} posts found for query: "$query"');
        return PostsResult.success(posts);
      } else {
        debugPrint('❌ [PostsService] Failed to search posts: ${response.error}');
        return PostsResult.failure(response.error ?? 'Erreur lors de la recherche');
      }
    } catch (e) {
      debugPrint('❌ [PostsService] Exception searching posts: $e');
      return PostsResult.failure('Erreur lors de la recherche');
    }
  }

  // MÉTHODES UTILITAIRES

  /// Vérifie si un post existe
  Future<bool> postExists(int postId) async {
    try {
      final result = await getPostById(postId);
      return result.isSuccess;
    } catch (e) {
      return false;
    }
  }

  /// Précharge les métadonnées d'un post (likes, commentaires)
  Future<PostMetadata?> getPostMetadata(int postId) async {
    try {
      debugPrint('📊 [PostsService] Fetching metadata for post: $postId');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        '/posts/$postId/metadata',
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        return PostMetadata(
          postId: postId,
          likesCount: data['likes_count'] ?? 0,
          commentsCount: data['comments_count'] ?? 0,
          isLiked: data['is_liked'] ?? false,
          viewsCount: data['views_count'] ?? 0,
        );
      }
      return null;
    } catch (e) {
      debugPrint('❌ [PostsService] Exception fetching metadata: $e');
      return null;
    }
  }
}


// CLASSES DE RÉSULTATS

/// Résultat pour un post unique
class PostResult {
  final bool isSuccess;
  final Post? data;
  final String? error;

  PostResult.success(this.data) : isSuccess = true, error = null;
  PostResult.failure(this.error) : isSuccess = false, data = null;
}

/// Résultat pour plusieurs posts
class PostsResult {
  final bool isSuccess;
  final List<Post>? data;
  final String? error;

  PostsResult.success(this.data) : isSuccess = true, error = null;
  PostsResult.failure(this.error) : isSuccess = false, data = null;
}

/// Résultat pour toggle like
class LikeToggleResult {
  final bool isSuccess;
  final bool? isLiked;
  final int? likesCount;
  final String? error;

  LikeToggleResult.success(this.isLiked, [this.likesCount]) : isSuccess = true, error = null;
  LikeToggleResult.failure(this.error) : isSuccess = false, isLiked = null, likesCount = null;
}

/// Résultat pour statut de like
class LikeStatusResult {
  final bool isSuccess;
  final int? likesCount;
  final bool? isLiked;
  final String? error;

  LikeStatusResult.success(this.likesCount, this.isLiked) : isSuccess = true, error = null;
  LikeStatusResult.failure(this.error) : isSuccess = false, likesCount = null, isLiked = null;
}

/// Résultat pour commentaires
class CommentsResult {
  final bool isSuccess;
  final List<Comment>? data;
  final String? error;

  CommentsResult.success(this.data) : isSuccess = true, error = null;
  CommentsResult.failure(this.error) : isSuccess = false, data = null;
}

/// Résultat pour un commentaire unique
class CommentResult {
  final bool isSuccess;
  final Comment? data;
  final String? error;

  CommentResult.success(this.data) : isSuccess = true, error = null;
  CommentResult.failure(this.error) : isSuccess = false, data = null;
}

/// Résultat générique pour les opérations simples
class ServiceResult {
  final bool isSuccess;
  final String? message;
  final String? error;

  ServiceResult.success(this.message) : isSuccess = true, error = null;
  ServiceResult.failure(this.error) : isSuccess = false, message = null;
}

/// Métadonnées d'un post
class PostMetadata {
  final int postId;
  final int likesCount;
  final int commentsCount;
  final bool isLiked;
  final int viewsCount;

  PostMetadata({
    required this.postId,
    required this.likesCount,
    required this.commentsCount,
    required this.isLiked,
    required this.viewsCount,
  });
}