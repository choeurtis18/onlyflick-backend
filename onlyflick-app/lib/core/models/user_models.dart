// lib/core/models/user_models.dart
import 'package:flutter/foundation.dart';

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
    };
  }

  String get displayName => fullName.isNotEmpty ? fullName : username;
  
  String get subscriptionPriceFormatted {
    if (subscriptionPrice == null) return '';
    return '${subscriptionPrice}€ / mois';
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
  String toString() => 'PublicUserProfile(id: $id, username: $username, role: $role)';
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