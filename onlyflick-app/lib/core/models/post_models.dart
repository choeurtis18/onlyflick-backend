// lib/core/models/post_models.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

/// Modèle pour un post avec informations utilisateur complètes
class Post {
  final int id;
  final int userId;
  final String title;
  final String description;
  final String mediaUrl;
  final String? fileId;
  final String? imageUrl;
  final String? videoUrl;
  final String visibility;
  final double? popularityScore;
  final List<String> tags; 
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // ===== NOUVELLES PROPRIÉTÉS UTILISATEUR =====
  final String authorUsername;    // Nom d'utilisateur de l'auteur
  final String authorFirstName;   // Prénom de l'auteur
  final String authorLastName;    // Nom de famille de l'auteur
  final String authorAvatarUrl;   // URL de l'avatar de l'auteur
  final String authorBio;         // Bio de l'auteur
  final String authorRole;        // Rôle de l'auteur (creator, subscriber, etc.)
  
  // ===== COMPTEURS INITIAUX =====
  final int initialLikesCount;    // Nombre de likes depuis la DB
  final int initialCommentsCount; // Nombre de commentaires depuis la DB

  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.mediaUrl,
    this.fileId,
    this.imageUrl,
    this.videoUrl,
    this.popularityScore,
    this.tags = const [],
    required this.visibility,
    required this.createdAt,
    required this.updatedAt,
    // ===== PARAMÈTRES UTILISATEUR AVEC VALEURS PAR DÉFAUT =====
    this.authorUsername = '',
    this.authorFirstName = '',
    this.authorLastName = '',
    this.authorAvatarUrl = '',
    this.authorBio = '',
    this.authorRole = 'subscriber',
    this.initialLikesCount = 0,
    this.initialCommentsCount = 0,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      fileId: json['file_id'],
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      popularityScore: (json['popularity_score'] as num?)?.toDouble(),
      tags: (json['tags'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      visibility: json['visibility'] ?? 'public',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      
      // ===== PARSING DES DONNÉES UTILISATEUR =====
      // Support de plusieurs formats de clés JSON (backend peut envoyer différents formats)
      authorUsername: json['author_username'] ?? 
                     json['username'] ?? 
                     json['user_username'] ??
                     'user${json['user_id'] ?? 'unknown'}',
      authorFirstName: json['author_first_name'] ?? 
                      json['first_name'] ?? 
                      json['user_first_name'] ?? '',
      authorLastName: json['author_last_name'] ?? 
                     json['last_name'] ?? 
                     json['user_last_name'] ?? '',
      authorAvatarUrl: json['author_avatar_url'] ?? 
                      json['avatar_url'] ?? 
                      json['user_avatar_url'] ?? '',
      authorBio: json['author_bio'] ?? 
                json['bio'] ?? 
                json['user_bio'] ?? '',
      authorRole: json['author_role'] ?? 
                 json['role'] ?? 
                 json['user_role'] ?? 'subscriber',
      
      // ===== COMPTEURS =====
      initialLikesCount: json['likes_count'] ?? 0,
      initialCommentsCount: json['comments_count'] ?? 0,
    );
  }

  bool get isSubscriberOnly => visibility == 'subscriber';
  bool get isPublic => visibility == 'public';
  
  /// Nom complet de l'auteur
  String get authorFullName => '$authorFirstName $authorLastName'.trim();
  
  /// Nom d'affichage de l'auteur (priorité au username)
  String get authorDisplayName {
    if (authorUsername.isNotEmpty && authorUsername != 'user${userId}unknown') {
      return authorUsername;
    }
    final fullName = authorFullName;
    return fullName.isNotEmpty ? fullName : 'Utilisateur $userId';
  }
  
  /// URL de l'avatar avec fallback
  String get authorAvatarFallback => authorAvatarUrl.isNotEmpty 
      ? authorAvatarUrl 
      : 'https://i.pravatar.cc/150?u=${authorUsername.isNotEmpty ? authorUsername : userId}';
  
  /// Vérifie si l'auteur est un créateur
  bool get isFromCreator => authorRole == 'creator';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'description': description,
      'media_url': mediaUrl,
      'file_id': fileId,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'popularity_score': popularityScore,
      'tags': tags,
      'visibility': visibility,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      
      // ===== DONNÉES UTILISATEUR =====
      'author_username': authorUsername,
      'author_first_name': authorFirstName,
      'author_last_name': authorLastName,
      'author_avatar_url': authorAvatarUrl,
      'author_bio': authorBio,
      'author_role': authorRole,
      
      // ===== COMPTEURS =====
      'likes_count': initialLikesCount,
      'comments_count': initialCommentsCount,
    };
  }

  Post copyWith({
    int? id,
    int? userId,
    String? title,
    String? description,
    String? mediaUrl,
    String? fileId,
    String? imageUrl,
    String? videoUrl,
    String? visibility,
    double? popularityScore,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,

    String? authorUsername,
    String? authorFirstName,
    String? authorLastName,
    String? authorAvatarUrl,
    String? authorBio,
    String? authorRole,
    int? initialLikesCount,
    int? initialCommentsCount,
  }) {
    return Post(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      fileId: fileId ?? this.fileId,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      visibility: visibility ?? this.visibility,
      popularityScore: popularityScore ?? this.popularityScore,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorUsername: authorUsername ?? this.authorUsername,
      authorFirstName: authorFirstName ?? this.authorFirstName,
      authorLastName: authorLastName ?? this.authorLastName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      authorBio: authorBio ?? this.authorBio,
      authorRole: authorRole ?? this.authorRole,
      initialLikesCount: initialLikesCount ?? this.initialLikesCount,
      initialCommentsCount: initialCommentsCount ?? this.initialCommentsCount,
    );
  }

  @override
  String toString() => 'Post(id: $id, title: $title, author: $authorDisplayName)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// ===== CLASSE POUR LA CRÉATION D'UN POST =====

/// Modèle pour créer un nouveau post (envoi au backend)
class CreatePostRequest {
  final String title;
  final String description;
  final File? imageFile;
  final String visibility;
  final List<String> tags; // ✅ Ajout des tags

  const CreatePostRequest({
    required this.title,
    required this.description,
    this.imageFile,
    required this.visibility,
    this.tags = const [], // ✅ Tags par défaut vide
  });

  /// Convertit en JSON pour l'envoi au backend
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'visibility': visibility,
      'tags': tags, // ✅ Inclure les tags
    };
  }

  /// Validation des données avant envoi
  bool get isValid {
    return title.trim().isNotEmpty && 
           description.trim().isNotEmpty && 
           imageFile != null &&
           ['public', 'subscriber'].contains(visibility);
  }

  /// Messages d'erreur de validation
  List<String> get validationErrors {
    List<String> errors = [];
    
    if (title.trim().isEmpty) {
      errors.add('Le titre est requis');
    }
    if (description.trim().isEmpty) {
      errors.add('La description est requise');
    }
    if (imageFile == null) {
      errors.add('Une image est requise');
    }
    if (!['public', 'subscriber'].contains(visibility)) {
      errors.add('Visibilité invalide');
    }
    
    return errors;
  }

  @override
  String toString() => 'CreatePostRequest(title: $title, tags: $tags, visibility: $visibility)';
}

/// Modèle pour un commentaire avec informations utilisateur
class Comment {
  final int id;
  final int postId;
  final int userId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // ===== INFORMATIONS UTILISATEUR =====
  final String authorUsername;
  final String authorFirstName;
  final String authorLastName;
  final String authorAvatarUrl;

  const Comment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.authorUsername = '',
    this.authorFirstName = '',
    this.authorLastName = '',
    this.authorAvatarUrl = '',
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      content: json['content'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      
      // ===== DONNÉES UTILISATEUR =====
      authorUsername: json['author_username'] ?? 
                     json['username'] ?? 
                     'user${json['user_id'] ?? 'unknown'}',
      authorFirstName: json['author_first_name'] ?? json['first_name'] ?? '',
      authorLastName: json['author_last_name'] ?? json['last_name'] ?? '',
      authorAvatarUrl: json['author_avatar_url'] ?? json['avatar_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_id': postId,
    'user_id': userId,
    'content': content,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'author_username': authorUsername,
    'author_first_name': authorFirstName,
    'author_last_name': authorLastName,
    'author_avatar_url': authorAvatarUrl,
    
  };

  /// Nom d'affichage de l'auteur
  String get authorDisplayName {
    if (authorUsername.isNotEmpty && !authorUsername.startsWith('user')) {
      return authorUsername;
    }
    final fullName = '$authorFirstName $authorLastName'.trim();
    return fullName.isNotEmpty ? fullName : 'Utilisateur $userId';
  }
  
  /// URL de l'avatar avec fallback
  String get authorAvatarFallback => authorAvatarUrl.isNotEmpty 
      ? authorAvatarUrl 
      : 'https://i.pravatar.cc/150?u=${authorUsername.isNotEmpty ? authorUsername : userId}';

  /// Calcule le temps écoulé depuis la création
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'maintenant';
    }
  }

  @override
  String toString() => 'Comment(id: $id, content: $content, author: $authorDisplayName)';
}

/// Énumération pour la visibilité des posts
enum PostVisibility {
  public('public'),
  subscriber('subscriber');

  const PostVisibility(this.value);
  final String value;

  String get displayName {
    switch (this) {
      case PostVisibility.public:
        return 'Public';
      case PostVisibility.subscriber:
        return 'Abonnés uniquement';
    }
  }

  String get description {
    switch (this) {
      case PostVisibility.public:
        return 'Visible par tous les utilisateurs';
      case PostVisibility.subscriber:
        return 'Visible uniquement par vos abonnés';
    }
  }

  IconData get icon {
    switch (this) {
      case PostVisibility.public:
        return Icons.public;
      case PostVisibility.subscriber:
        return Icons.lock;
    }
  }

  /// Convertit une string en PostVisibility
  static PostVisibility fromString(String value) {
    switch (value.toLowerCase()) {
      case 'subscriber':
        return PostVisibility.subscriber;
      case 'public':
      default:
        return PostVisibility.public;
    }
  }
}

/// Résultat de création/modification de post
class PostCreationResult {
  final bool isSuccess;
  final Post? data;
  final String? error;

  const PostCreationResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory PostCreationResult.success(Post post) {
    return PostCreationResult._(
      isSuccess: true,
      data: post,
    );
  }

  factory PostCreationResult.failure(String error) {
    return PostCreationResult._(
      isSuccess: false,
      error: error,
    );
  }

  bool get isFailure => !isSuccess;
}

// ===== CLASSES DE RÉSULTATS POUR LES SERVICES =====

/// Résultat pour une liste de posts
class PostsResult {
  final bool isSuccess;
  final List<Post>? data;
  final String? error;

  const PostsResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory PostsResult.success(List<Post> data) {
    return PostsResult._(isSuccess: true, data: data);
  }

  factory PostsResult.failure(String error) {
    return PostsResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
}

/// Résultat pour le toggle d'un like
class LikeToggleResult {
  final bool isSuccess;
  final bool? data; // true = liké, false = unlike
  final String? error;

  const LikeToggleResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory LikeToggleResult.success(bool isLiked) {
    return LikeToggleResult._(isSuccess: true, data: isLiked);
  }

  factory LikeToggleResult.failure(String error) {
    return LikeToggleResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
}

/// Résultat pour le nombre de likes
class LikesCountResult {
  final bool isSuccess;
  final int? data;
  final String? error;

  const LikesCountResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory LikesCountResult.success(int count) {
    return LikesCountResult._(isSuccess: true, data: count);
  }

  factory LikesCountResult.failure(String error) {
    return LikesCountResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
}

/// Résultat pour une liste de commentaires
class CommentsResult {
  final bool isSuccess;
  final List<Comment>? data;
  final String? error;

  const CommentsResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory CommentsResult.success(List<Comment> data) {
    return CommentsResult._(isSuccess: true, data: data);
  }

  factory CommentsResult.failure(String error) {
    return CommentsResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
}

/// Résultat pour la création d'un commentaire
class CommentResult {
  final bool isSuccess;
  final Comment? data;
  final String? error;

  const CommentResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory CommentResult.success(Comment data) {
    return CommentResult._(isSuccess: true, data: data);
  }

  factory CommentResult.failure(String error) {
    return CommentResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;
}

/// Extensions pour les fichiers média
extension MediaValidation on File {
  /// Vérifie si le fichier est une image valide
  bool get isValidImage {
    final extension = path.extension(this.path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif'].contains(extension);
  }

  /// Vérifie la taille du fichier (max 10MB)
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