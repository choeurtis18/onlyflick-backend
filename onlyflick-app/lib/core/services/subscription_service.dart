// lib/services/subscription_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/subscription_model.dart';
import '../utils/constants.dart';
import '../utils/auth_storage.dart';

class SubscriptionService {
  static const String _baseUrl = ApiConstants.baseUrl;

  // Récupérer les abonnés d'un utilisateur (créateur)
  static Future<SubscriptionListResponse> getFollowers(int userId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId/followers'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SubscriptionListResponse.fromJson({
          'subscriptions': data['followers'] ?? [],
          'total': data['total'] ?? 0,
          'type': 'followers',
        });
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else {
        throw Exception('Erreur lors de la récupération des abonnés: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Récupérer les abonnements d'un utilisateur (à qui il est abonné)
  static Future<SubscriptionListResponse> getFollowing(int userId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId/following'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SubscriptionListResponse.fromJson({
          'subscriptions': data['following'] ?? [],
          'total': data['total'] ?? 0,
          'type': 'following',
        });
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else {
        throw Exception('Erreur lors de la récupération des abonnements: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // S'abonner à un créateur
  static Future<bool> followCreator(int creatorId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/follow/$creatorId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else if (response.statusCode == 409) {
        throw Exception('Vous êtes déjà abonné à ce créateur');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'abonnement');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Se désabonner d'un créateur
  static Future<bool> unfollowCreator(int creatorId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/follow/$creatorId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else if (response.statusCode == 404) {
        throw Exception('Abonnement non trouvé');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors du désabonnement');
      }
    } catch (e) {
      throw Exception('Erreur réseau: $e');
    }
  }

  // Vérifier le statut d'abonnement à un créateur
  static Future<bool> isFollowing(int creatorId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        return false;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/users/$creatorId/subscription-status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_subscribed'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Obtenir les statistiques d'abonnements pour un utilisateur
  static Future<Map<String, int>> getSubscriptionStats(int userId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId/stats'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'followers_count': data['stats']['followers_count'] ?? 0,
          'following_count': data['stats']['following_count'] ?? 0,
          'posts_count': data['stats']['posts_count'] ?? 0,
        };
      } else {
        throw Exception('Erreur lors de la récupération des statistiques');
      }
    } catch (e) {
      return {
        'followers_count': 0,
        'following_count': 0,
        'posts_count': 0,
      };
    }
  }
}