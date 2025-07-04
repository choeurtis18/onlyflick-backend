// lib/models/subscription_model.dart

class Subscription {
  final int id;
  final int subscriberId;
  final int creatorId;
  final bool status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Informations utilisateur associées
  final UserProfile? subscriberProfile;
  final UserProfile? creatorProfile;

  Subscription({
    required this.id,
    required this.subscriberId,
    required this.creatorId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.subscriberProfile,
    this.creatorProfile,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] ?? 0,
      subscriberId: json['subscriber_id'] ?? 0,
      creatorId: json['creator_id'] ?? 0,
      status: json['status'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      subscriberProfile: json['subscriber_profile'] != null 
          ? UserProfile.fromJson(json['subscriber_profile']) 
          : null,
      creatorProfile: json['creator_profile'] != null 
          ? UserProfile.fromJson(json['creator_profile']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscriber_id': subscriberId,
      'creator_id': creatorId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'subscriber_profile': subscriberProfile?.toJson(),
      'creator_profile': creatorProfile?.toJson(),
    };
  }
}

// Modèle simplifié pour UserProfile (si pas déjà existant)
class UserProfile {
  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role;
  final String? avatarUrl;
  final String? bio;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? 0,
      username: json['username'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      fullName: json['full_name'] ?? '${json['first_name'] ?? ''} ${json['last_name'] ?? ''}',
      role: json['role'] ?? 'subscriber',
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
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
    };
  }
}

// Modèle pour la réponse de la liste des abonnements
class SubscriptionListResponse {
  final List<Subscription> subscriptions;
  final int total;
  final String type; // "followers" ou "following"

  SubscriptionListResponse({
    required this.subscriptions,
    required this.total,
    required this.type,
  });

  factory SubscriptionListResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionListResponse(
      subscriptions: (json['subscriptions'] as List<dynamic>?)
          ?.map((item) => Subscription.fromJson(item))
          .toList() ?? [],
      total: json['total'] ?? 0,
      type: json['type'] ?? '',
    );
  }
}