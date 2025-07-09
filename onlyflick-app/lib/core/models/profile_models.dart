// lib/core/models/profile_models.dart
import '../../features/auth/models/auth_models.dart';

// ===== MODÈLES DE DONNÉES PROFIL =====

/// Statistiques du profil utilisateur
class ProfileStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int likesReceived;
  final double totalEarnings;

  const ProfileStats({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.likesReceived,
    required this.totalEarnings,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      postsCount: json['posts_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      likesReceived: json['likes_received'] ?? 0,
      totalEarnings: (json['total_earnings'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'posts_count': postsCount,
    'followers_count': followersCount,
    'following_count': followingCount,
    'likes_received': likesReceived,
    'total_earnings': totalEarnings,
  };

  /// Stats par défaut pour l'état de chargement
  factory ProfileStats.empty() {
    return const ProfileStats(
      postsCount: 0,
      followersCount: 0,
      followingCount: 0,
      likesReceived: 0,
      totalEarnings: 0.0,
    );
  }

  /// Copie avec modification
  ProfileStats copyWith({
    int? postsCount,
    int? followersCount,
    int? followingCount,
    int? likesReceived,
    double? totalEarnings,
  }) {
    return ProfileStats(
      postsCount: postsCount ?? this.postsCount,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      likesReceived: likesReceived ?? this.likesReceived,
      totalEarnings: totalEarnings ?? this.totalEarnings,
    );
  }

  @override
  String toString() => 'ProfileStats(posts: $postsCount, followers: $followersCount, earnings: \$${totalEarnings.toStringAsFixed(2)})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProfileStats &&
        other.postsCount == postsCount &&
        other.followersCount == followersCount &&
        other.followingCount == followingCount &&
        other.likesReceived == likesReceived &&
        other.totalEarnings == totalEarnings;
  }

  @override
  int get hashCode => Object.hash(postsCount, followersCount, followingCount, likesReceived, totalEarnings);
}

/// Post utilisateur pour le profil
class UserPost {
  final int id;
  final String content;
  final String imageUrl;
  final String videoUrl;
  final String visibility;
  final int likesCount;
  final int commentsCount;
  final String createdAt;
  final bool isLiked;

  const UserPost({
    required this.id,
    required this.content,
    required this.imageUrl,
    required this.videoUrl,
    required this.visibility,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.isLiked,
  });

  factory UserPost.fromJson(Map<String, dynamic> json) {
    return UserPost(
      id: json['id'] ?? 0,
      content: json['content'] ?? '',
      imageUrl: json['image_url'] ?? '',
      videoUrl: json['video_url'] ?? '',
      visibility: json['visibility'] ?? 'public',
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      isLiked: json['is_liked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'image_url': imageUrl,
    'video_url': videoUrl,
    'visibility': visibility,
    'likes_count': likesCount,
    'comments_count': commentsCount,
    'created_at': createdAt,
    'is_liked': isLiked,
  };

  /// Copie avec modification
  UserPost copyWith({
    int? id,
    String? content,
    String? imageUrl,
    String? videoUrl,
    String? visibility,
    int? likesCount,
    int? commentsCount,
    String? createdAt,
    bool? isLiked,
  }) {
    return UserPost(
      id: id ?? this.id,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      visibility: visibility ?? this.visibility,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  /// Vérifie si le post a une image
  bool get hasImage => imageUrl.isNotEmpty;

  /// Vérifie si le post a une vidéo
  bool get hasVideo => videoUrl.isNotEmpty;

  /// Retourne le type de média
  String get mediaType {
    if (hasVideo) return 'video';
    if (hasImage) return 'image';
    return 'text';
  }

  /// Icône de visibilité
  String get visibilityIcon {
    switch (visibility) {
      case 'public':
        return '🌍';
      case 'subscriber':
        return '🔒';
      default:
        return '📄';
    }
  }

  /// Couleur de visibilité
  String get visibilityColor {
    switch (visibility) {
      case 'public':
        return '#4CAF50'; // Vert
      case 'subscriber':
        return '#FF9800'; // Orange
      default:
        return '#9E9E9E'; // Gris
    }
  }

  @override
  String toString() => 'UserPost(id: $id, content: ${content.substring(0, content.length.clamp(0, 50))}...)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserPost && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Réponse d'upload d'avatar
class AvatarUploadResponse {
  final String message;
  final String avatarUrl;

  const AvatarUploadResponse({
    required this.message,
    required this.avatarUrl,
  });

  factory AvatarUploadResponse.fromJson(Map<String, dynamic> json) {
    return AvatarUploadResponse(
      message: json['message'] ?? 'Avatar mis à jour',
      avatarUrl: json['avatar_url'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'message': message,
    'avatar_url': avatarUrl,
  };

  @override
  String toString() => 'AvatarUploadResponse(message: $message, url: $avatarUrl)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AvatarUploadResponse &&
        other.message == message &&
        other.avatarUrl == avatarUrl;
  }

  @override
  int get hashCode => Object.hash(message, avatarUrl);
}

/// Réponse de vérification de username
class UsernameCheckResponse {
  final String username;
  final bool available;

  const UsernameCheckResponse({
    required this.username,
    required this.available,
  });

  factory UsernameCheckResponse.fromJson(Map<String, dynamic> json) {
    return UsernameCheckResponse(
      username: json['username'] ?? '',
      available: json['available'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'available': available,
  };

  @override
  String toString() => 'UsernameCheckResponse(username: $username, available: $available)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UsernameCheckResponse &&
        other.username == username &&
        other.available == available;
  }

  @override
  int get hashCode => Object.hash(username, available);
}

// ===== RÉSULTATS D'OPÉRATIONS =====

/// Résultat pour les statistiques profil
class ProfileStatsResult {
  final bool isSuccess;
  final ProfileStats? data;
  final AuthError? error;

  const ProfileStatsResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory ProfileStatsResult.success(ProfileStats data) {
    return ProfileStatsResult._(isSuccess: true, data: data);
  }

  factory ProfileStatsResult.failure(AuthError error) {
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
  final AuthError? error;

  const UserPostsResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory UserPostsResult.success(List<UserPost> data) {
    return UserPostsResult._(isSuccess: true, data: data);
  }

  factory UserPostsResult.failure(AuthError error) {
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
  final AuthError? error;

  const AvatarUploadResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory AvatarUploadResult.success(AvatarUploadResponse data) {
    return AvatarUploadResult._(isSuccess: true, data: data);
  }

  factory AvatarUploadResult.failure(AuthError error) {
    return AvatarUploadResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'AvatarUploadResult.success($data)' 
      : 'AvatarUploadResult.failure($error)';
}

/// Résultat pour la mise à jour de bio
class BioUpdateResult {
  final bool isSuccess;
  final AuthError? error;

  const BioUpdateResult._({
    required this.isSuccess,
    this.error,
  });

  factory BioUpdateResult.success() {
    return const BioUpdateResult._(isSuccess: true);
  }

  factory BioUpdateResult.failure(AuthError error) {
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
  final UsernameCheckResponse? data;
  final AuthError? error;

  const UsernameCheckResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory UsernameCheckResult.success(UsernameCheckResponse data) {
    return UsernameCheckResult._(isSuccess: true, data: data);
  }

  factory UsernameCheckResult.failure(AuthError error) {
    return UsernameCheckResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'UsernameCheckResult.success($data)' 
      : 'UsernameCheckResult.failure($error)';
}