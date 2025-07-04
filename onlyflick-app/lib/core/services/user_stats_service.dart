// lib/services/user_stats_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../utils/auth_storage.dart';

class UserStatsService {
  static const String _baseUrl = ApiConstants.baseUrl;

  // Modèle pour les statistiques utilisateur depuis /profile/stats
  static Future<UserStats> getUserStats(int userId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      // ✅ CORRECTION: Essayer d'abord sans /api, puis avec /api
      String url = 'http://localhost:8080/profile/stats';
      
      var response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      // Si 404, essayer avec /api
      if (response.statusCode == 404) {
        url = 'http://localhost:8080/api/profile/stats';
        response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // ✅ CORRECTION: Parser la réponse directement (pas de nested 'stats')
        return UserStats(
          postsCount: data['posts_count'] ?? 0,
          followersCount: data['followers_count'] ?? 0,
          followingCount: data['following_count'] ?? 0,
          likesReceived: data['likes_received'] ?? 0,
          totalEarnings: (data['total_earnings'] ?? 0).toDouble(),
        );
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else {
        throw Exception('Erreur lors de la récupération des statistiques: ${response.statusCode} - URL testée: $url');
      }
    } catch (e) {
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
}

// ✅ CORRECTION: Modèle mis à jour avec tous les champs
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