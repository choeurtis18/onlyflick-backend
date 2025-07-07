// lib/core/services/user_stats_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/auth_storage.dart';

class UserStatsService {
  static const String _baseUrl = ApiConstants.baseUrl;

  // Récupérer les statistiques depuis /profile/stats
  static Future<UserStats> getUserStats(int userId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final url = '$_baseUrl/profile/stats';
      print('🌐 [UserStatsService] Calling getUserStats: $url'); // Debug
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [UserStatsService] getUserStats status: ${response.statusCode}'); // Debug
      print('🔍 [UserStatsService] getUserStats body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parser la réponse directement 
        return UserStats(
          postsCount: data['posts_count'] ?? 0,
          followersCount: data['followers_count'] ?? 0,
          followingCount: data['following_count'] ?? 0,
          likesReceived: data['likes_received'] ?? 0,
          totalEarnings: (data['total_earnings'] ?? 0).toDouble(),
        );
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint non trouvé: $url');
      } else {
        throw Exception('Erreur lors de la récupération des statistiques: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [UserStatsService] Error: $e'); // Debug
      throw Exception('Erreur réseau: $e');
    }
  }

  // Récupérer uniquement les statistiques d'abonnements
  static Future<SubscriptionStats> getSubscriptionStats(int userId) async {
    try {
      final userStats = await getUserStats(userId);
      return SubscriptionStats(
        followersCount: userStats.followersCount,
        followingCount: userStats.followingCount,
      );
    } catch (e) {
      throw Exception('Erreur récupération stats abonnements: $e');
    }
  }

  // Récupérer les statistiques pour un utilisateur spécifique (public)
  static Future<PublicUserStats> getPublicUserStats(int userId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final url = '$_baseUrl/users/$userId/stats';
      print('🌐 [UserStatsService] Calling getPublicUserStats: $url'); // Debug
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [UserStatsService] getPublicUserStats status: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        return PublicUserStats(
          postsCount: data['posts_count'] ?? 0,
          followersCount: data['followers_count'] ?? 0,
          followingCount: data['following_count'] ?? 0,
        );
      } else if (response.statusCode == 404) {
        // Si l'endpoint n'existe pas, retourner des stats vides
        return PublicUserStats(
          postsCount: 0,
          followersCount: 0,
          followingCount: 0,
        );
      } else {
        throw Exception('Erreur lors de la récupération des statistiques publiques: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [UserStatsService] getPublicUserStats error: $e'); // Debug
      // Retourner des stats vides en cas d'erreur
      return PublicUserStats(
        postsCount: 0,
        followersCount: 0,
        followingCount: 0,
      );
    }
  }
}

// Modèle complet pour les statistiques utilisateur
class UserStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final int likesReceived;
  final double totalEarnings;

  UserStats({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
    required this.likesReceived,
    required this.totalEarnings,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      postsCount: json['posts_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
      likesReceived: json['likes_received'] ?? 0,
      totalEarnings: (json['total_earnings'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posts_count': postsCount,
      'followers_count': followersCount,
      'following_count': followingCount,
      'likes_received': likesReceived,
      'total_earnings': totalEarnings,
    };
  }
}

// Modèle spécialisé pour les abonnements
class SubscriptionStats {
  final int followersCount;
  final int followingCount;

  SubscriptionStats({
    required this.followersCount,
    required this.followingCount,
  });

  factory SubscriptionStats.fromJson(Map<String, dynamic> json) {
    return SubscriptionStats(
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'followers_count': followersCount,
      'following_count': followingCount,
    };
  }
}

// Modèle pour les statistiques publiques d'un autre utilisateur
class PublicUserStats {
  final int postsCount;
  final int followersCount;
  final int followingCount;

  PublicUserStats({
    required this.postsCount,
    required this.followersCount,
    required this.followingCount,
  });

  factory PublicUserStats.fromJson(Map<String, dynamic> json) {
    return PublicUserStats(
      postsCount: json['posts_count'] ?? 0,
      followersCount: json['followers_count'] ?? 0,
      followingCount: json['following_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posts_count': postsCount,
      'followers_count': followersCount,
      'following_count': followingCount,
    };
  }
}