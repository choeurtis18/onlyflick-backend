// lib/core/models/user_models.dart
import 'package:flutter/foundation.dart';

/// Statistiques d'un utilisateur dans le profil public
class UserStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;

  const UserStats({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      postsCount: json['posts_count']?.toInt() ?? 0,
      followersCount: json['followers_count']?.toInt() ?? 0,
      followingCount: json['following_count']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posts_count': postsCount,
      'followers_count': followersCount,
      'following_count': followingCount,
    };
  }

  /// Stats par défaut pour l'état de chargement
  factory UserStats.empty() {
    return const UserStats(
      postsCount: 0,
      followersCount: 0,
      followingCount: 0,
    );
  }

  @override
  String toString() => 'UserStats(posts: $postsCount, followers: $followersCount, following: $followingCount)';
}

/// Modèle pour le profil public d'un utilisateur
/// Utilisé pour afficher les profils des autres utilisateurs
class PublicUserProfile {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;
  final bool isCreator;
  final String? subscriptionPrice;
  final String? currency;
  final ViewerSubscription? viewerSubscription;
  // ===== NOUVEAU : Ajout des statistiques =====
  final UserStats stats;

  const PublicUserProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
    required this.isCreator,
    this.subscriptionPrice,
    this.currency,
    this.viewerSubscription,
    // ===== NOUVEAU : Stats avec valeur par défaut =====
    this.stats = const UserStats(postsCount: 0, followersCount: 0, followingCount: 0),
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      id: json['id']?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'subscriber',
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      isCreator: json['is_creator'] == true,
      subscriptionPrice: json['subscription_price']?.toString(),
      currency: json['currency']?.toString(),
      viewerSubscription: json['viewer_subscription'] != null
          ? ViewerSubscription.fromJson(json['viewer_subscription'])
          : null,
      // ===== NOUVEAU : Parsing des statistiques =====
      stats: json['stats'] != null
          ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
          : UserStats.empty(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
      'is_creator': isCreator,
      'subscription_price': subscriptionPrice,
      'currency': currency,
      'viewer_subscription': viewerSubscription?.toJson(),
      // ===== NOUVEAU : Sérialisation des statistiques =====
      'stats': stats.toJson(),
    };
  }

  String get displayName => fullName.isNotEmpty ? fullName : username;
  
  String get subscriptionPriceFormatted {
    if (subscriptionPrice == null) return '';
    return '${subscriptionPrice}€ / mois';
  }

  /// ===== NOUVEAU : Formatage des statistiques pour l'affichage =====
  String get followersCountFormatted => _formatCount(stats.followersCount);
  String get followingCountFormatted => _formatCount(stats.followingCount);
  String get postsCountFormatted => _formatCount(stats.postsCount);

  /// Formatte les grands nombres (ex: 1.2K, 12.5K, 1.1M)
  String _formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      double thousands = count / 1000;
      if (thousands == thousands.round()) {
        return '${thousands.round()}K';
      }
      return '${thousands.toStringAsFixed(1)}K';
    } else {
      double millions = count / 1000000;
      if (millions == millions.round()) {
        return '${millions.round()}M';
      }
      return '${millions.toStringAsFixed(1)}M';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PublicUserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PublicUserProfile(id: $id, username: $username, role: $role, stats: $stats)';
}

/// Informations d'abonnement du viewer pour un créateur
class ViewerSubscription {
  final bool isSubscribed;
  final String status; // 'active', 'inactive', 'none'

  const ViewerSubscription({
    required this.isSubscribed,
    required this.status,
  });

  factory ViewerSubscription.fromJson(Map<String, dynamic> json) {
    return ViewerSubscription(
      isSubscribed: json['is_subscribed'] == true,
      status: json['status']?.toString() ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_subscribed': isSubscribed,
      'status': status,
    };
  }

  bool get isActive => status == 'active' && isSubscribed;
  bool get isInactive => status == 'inactive';
  bool get hasNoSubscription => status == 'none';

  @override
  String toString() => 'ViewerSubscription(isSubscribed: $isSubscribed, status: $status)';
}

/// Modèle pour les résultats de recherche d'utilisateurs
class UserSearchResult {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final bool isCreator;
  final int followersCount;
  final int postsCount;
  final bool isFollowing;
  final int mutualFollowers;

  const UserSearchResult({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.bio,
    required this.isCreator,
    this.followersCount = 0,
    this.postsCount = 0,
    this.isFollowing = false,
    this.mutualFollowers = 0,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id']?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'subscriber',
      avatarUrl: json['avatar_url']?.toString().isEmpty == true ? null : json['avatar_url']?.toString(),
      bio: json['bio']?.toString().isEmpty == true ? null : json['bio']?.toString(),
      isCreator: json['role'] == 'creator',
      followersCount: json['followers_count']?.toInt() ?? 0,
      postsCount: json['posts_count']?.toInt() ?? 0,
      isFollowing: json['is_following'] == true,
      mutualFollowers: json['mutual_followers']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'role': role,
      'avatar_url': avatarUrl,
      'bio': bio,
      'is_creator': isCreator,
      'followers_count': followersCount,
      'posts_count': postsCount,
      'is_following': isFollowing,
      'mutual_followers': mutualFollowers,
    };
  }

  String get displayName => fullName.isNotEmpty ? fullName : username;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSearchResult &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserSearchResult(id: $id, username: $username, role: $role)';
}

/// Modèle pour le statut d'abonnement détaillé
class SubscriptionStatus {
  final int creatorId;
  final String creatorName;
  final bool isSubscribed;
  final String status; // 'active', 'inactive', 'none'
  final SubscriptionDetails? subscription;

  const SubscriptionStatus({
    required this.creatorId,
    required this.creatorName,
    required this.isSubscribed,
    required this.status,
    this.subscription,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      creatorId: json['creator_id']?.toInt() ?? 0,
      creatorName: json['creator_name']?.toString() ?? '',
      isSubscribed: json['is_subscribed'] == true,
      status: json['status']?.toString() ?? 'none',
      subscription: json['subscription'] != null
          ? SubscriptionDetails.fromJson(json['subscription'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'creator_id': creatorId,
      'creator_name': creatorName,
      'is_subscribed': isSubscribed,
      'status': status,
      'subscription': subscription?.toJson(),
    };
  }

  bool get isActive => status == 'active' && isSubscribed;
  bool get isInactive => status == 'inactive';
  bool get hasNoSubscription => status == 'none';

  @override
  String toString() => 'SubscriptionStatus(creatorId: $creatorId, status: $status)';
}

/// Détails d'un abonnement
class SubscriptionDetails {
  final int id;
  final DateTime createdAt;
  final DateTime endAt;
  final bool status;
  final String? paymentIntentId;

  const SubscriptionDetails({
    required this.id,
    required this.createdAt,
    required this.endAt,
    required this.status,
    this.paymentIntentId,
  });

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetails(
      id: json['id']?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      endAt: DateTime.tryParse(json['end_at']?.toString() ?? '') ?? DateTime.now(),
      status: json['status'] == true,
      paymentIntentId: json['payment_intent_id']?.toString().isEmpty == true 
          ? null 
          : json['payment_intent_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'created_at': createdAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'status': status,
      'payment_intent_id': paymentIntentId,
    };
  }

  bool get isExpired => DateTime.now().isAfter(endAt);
  bool get isActive => status && !isExpired;

  Duration get timeUntilExpiry => endAt.difference(DateTime.now());
  
  String get formattedEndDate {
    final now = DateTime.now();
    final difference = endAt.difference(now);
    
    if (difference.isNegative) {
      return 'Expiré';
    } else if (difference.inDays > 0) {
      return 'Expire dans ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Expire dans ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'Expire bientôt';
    }
  }

  @override
  String toString() => 'SubscriptionDetails(id: $id, status: $status, endAt: $endAt)';
}

/// Modèle pour un abonnement complet (utilisé dans la liste des abonnements)
class Subscription {
  final int id;
  final int subscriberId;
  final int creatorId;
  final DateTime createdAt;
  final DateTime endAt;
  final bool status;
  final String? paymentIntentId;

  const Subscription({
    required this.id,
    required this.subscriberId,
    required this.creatorId,
    required this.createdAt,
    required this.endAt,
    required this.status,
    this.paymentIntentId,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toInt() ?? 0,
      subscriberId: json['subscriber_id']?.toInt() ?? 0,
      creatorId: json['creator_id']?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      endAt: DateTime.tryParse(json['end_at']?.toString() ?? '') ?? DateTime.now(),
      status: json['status'] == true,
      paymentIntentId: json['payment_intent_id']?.toString().isEmpty == true 
          ? null 
          : json['payment_intent_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscriber_id': subscriberId,
      'creator_id': creatorId,
      'created_at': createdAt.toIso8601String(),
      'end_at': endAt.toIso8601String(),
      'status': status,
      'payment_intent_id': paymentIntentId,
    };
  }

  bool get isExpired => DateTime.now().isAfter(endAt);
  bool get isActive => status && !isExpired;

  Duration get timeUntilExpiry => endAt.difference(DateTime.now());
  
  String get formattedEndDate {
    final now = DateTime.now();
    final difference = endAt.difference(now);
    
    if (difference.isNegative) {
      return 'Expiré';
    } else if (difference.inDays > 0) {
      return 'Expire dans ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Expire dans ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else {
      return 'Expire bientôt';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Subscription(id: $id, creatorId: $creatorId, status: $status)';
}

/// Résultat de recherche d'utilisateurs avec pagination
class UserSearchResponse {
  final List<UserSearchResult> users;
  final int total;
  final bool hasMore;
  final int limit;
  final int offset;
  final String query;

  const UserSearchResponse({
    required this.users,
    required this.total,
    required this.hasMore,
    required this.limit,
    required this.offset,
    required this.query,
  });

  factory UserSearchResponse.fromJson(Map<String, dynamic> json) {
    final usersList = json['users'] as List? ?? [];
    
    return UserSearchResponse(
      users: usersList
          .map((user) => UserSearchResult.fromJson(user as Map<String, dynamic>))
          .toList(),
      total: json['total']?.toInt() ?? 0,
      hasMore: json['has_more'] == true,
      limit: json['limit']?.toInt() ?? 20,
      offset: json['offset']?.toInt() ?? 0,
      query: json['query']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'users': users.map((user) => user.toJson()).toList(),
      'total': total,
      'has_more': hasMore,
      'limit': limit,
      'offset': offset,
      'query': query,
    };
  }

  bool get isEmpty => users.isEmpty;
  bool get isNotEmpty => users.isNotEmpty;

  @override
  String toString() => 'UserSearchResponse(query: $query, total: $total, count: ${users.length})';
}

/// ===== NOUVEAU : Modèle pour les posts d'un utilisateur =====

/// Post d'un utilisateur pour le profil public
class UserPost {
  final int id;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final String visibility;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final bool isLiked;

  const UserPost({
    required this.id,
    required this.content,
    this.imageUrl,
    this.videoUrl,
    required this.visibility,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.isLiked,
  });

  factory UserPost.fromJson(Map<String, dynamic> json) {
    return UserPost(
      id: json['id']?.toInt() ?? 0,
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString().isEmpty == true ? null : json['image_url']?.toString(),
      videoUrl: json['video_url']?.toString().isEmpty == true ? null : json['video_url']?.toString(),
      visibility: json['visibility']?.toString() ?? 'public',
      likesCount: json['likes_count']?.toInt() ?? 0,
      commentsCount: json['comments_count']?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      isLiked: json['is_liked'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'visibility': visibility,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'is_liked': isLiked,
    };
  }

  bool get isPublic => visibility == 'public';
  bool get isSubscriberOnly => visibility == 'subscriber';
  bool get hasMedia => imageUrl != null || videoUrl != null;

  String get formattedCreatedAt {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'Maintenant';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPost &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'UserPost(id: $id, content: $content, visibility: $visibility)';
}

/// Réponse de l'API pour les posts d'un utilisateur
class UserPostsResponse {
  final List<UserPost> posts;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
  final String postType;
  final int userId;

  const UserPostsResponse({
    required this.posts,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.postType,
    required this.userId,
  });

  factory UserPostsResponse.fromJson(Map<String, dynamic> json) {
    final postsList = json['posts'] as List? ?? [];
    
    return UserPostsResponse(
      posts: postsList
          .map((post) => UserPost.fromJson(post as Map<String, dynamic>))
          .toList(),
      total: json['total']?.toInt() ?? 0,
      page: json['page']?.toInt() ?? 1,
      limit: json['limit']?.toInt() ?? 20,
      hasMore: json['has_more'] == true,
      postType: json['post_type']?.toString() ?? 'public',
      userId: json['user_id']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posts': posts.map((post) => post.toJson()).toList(),
      'total': total,
      'page': page,
      'limit': limit,
      'has_more': hasMore,
      'post_type': postType,
      'user_id': userId,
    };
  }

  bool get isEmpty => posts.isEmpty;
  bool get isNotEmpty => posts.isNotEmpty;

  @override
  String toString() => 'UserPostsResponse(userId: $userId, total: $total, count: ${posts.length}, type: $postType)';
}