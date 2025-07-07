// lib/core/services/subscription_service.dart

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

      final url = '$_baseUrl/users/$userId/followers';
      print('🌐 [SubscriptionService] Calling getFollowers: $url'); // Debug
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] getFollowers status: ${response.statusCode}'); // Debug
      print('🔍 [SubscriptionService] getFollowers body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Adapter la réponse API à notre modèle
        return SubscriptionListResponse(
          subscriptions: (data['followers'] as List<dynamic>?)
              ?.map((item) => Subscription.fromJson(item))
              .toList() ?? [],
          total: data['total'] ?? 0,
          type: 'followers',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint non trouvé. Vérifiez que le backend est démarré et que l\'URL est correcte: $url');
      } else {
        throw Exception('Erreur lors de la récupération des abonnés: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [SubscriptionService] getFollowers error: $e'); // Debug
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

      final url = '$_baseUrl/users/$userId/following';
      print('🌐 [SubscriptionService] Calling getFollowing: $url'); // Debug
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] getFollowing status: ${response.statusCode}'); // Debug
      print('🔍 [SubscriptionService] getFollowing body: ${response.body}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Adapter la réponse API à notre modèle
        return SubscriptionListResponse(
          subscriptions: (data['following'] as List<dynamic>?)
              ?.map((item) => Subscription.fromJson(item))
              .toList() ?? [],
          total: data['total'] ?? 0,
          type: 'following',
        );
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint non trouvé. Vérifiez que le backend est démarré et que l\'URL est correcte: $url');
      } else {
        throw Exception('Erreur lors de la récupération des abonnements: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [SubscriptionService] getFollowing error: $e'); // Debug
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

      final url = '$_baseUrl/follow/$creatorId';
      print('🌐 [SubscriptionService] Calling followCreator: $url'); // Debug

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] followCreator status: ${response.statusCode}'); // Debug

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else if (response.statusCode == 409) {
        throw Exception('Vous êtes déjà abonné à ce créateur');
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint non trouvé: $url');
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors de l\'abonnement');
        } catch (jsonError) {
          throw Exception('Erreur lors de l\'abonnement: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ [SubscriptionService] followCreator error: $e'); // Debug
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

      final url = '$_baseUrl/follow/$creatorId';
      print('🌐 [SubscriptionService] Calling unfollowCreator: $url'); // Debug

      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] unfollowCreator status: ${response.statusCode}'); // Debug

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else if (response.statusCode == 404) {
        throw Exception('Abonnement non trouvé ou endpoint non trouvé: $url');
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['message'] ?? 'Erreur lors du désabonnement');
        } catch (jsonError) {
          throw Exception('Erreur lors du désabonnement: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('❌ [SubscriptionService] unfollowCreator error: $e'); // Debug
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

      final url = '$_baseUrl/users/$creatorId/subscription-status';
      print('🌐 [SubscriptionService] Calling isFollowing: $url'); // Debug

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] isFollowing status: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['is_subscribed'] ?? false;
      }
      return false;
    } catch (e) {
      print('❌ [SubscriptionService] isFollowing error: $e'); // Debug
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

      final url = '$_baseUrl/users/$userId/stats';
      print('🌐 [SubscriptionService] Calling getSubscriptionStats: $url'); // Debug

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] getSubscriptionStats status: ${response.statusCode}'); // Debug

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'followers_count': data['stats']['followers_count'] ?? 0,
          'following_count': data['stats']['following_count'] ?? 0,
          'posts_count': data['stats']['posts_count'] ?? 0,
        };
      } else if (response.statusCode == 404) {
        throw Exception('Endpoint non trouvé: $url');
      } else {
        throw Exception('Erreur lors de la récupération des statistiques: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [SubscriptionService] getSubscriptionStats error: $e'); // Debug
      return {
        'followers_count': 0,
        'following_count': 0,
        'posts_count': 0,
      };
    }
  }

  // ========= MÉTHODES POUR PAIEMENTS =========

  /// S'abonner à un créateur avec paiement
  /// Retourne le client_secret pour Stripe
  static Future<Map<String, dynamic>> subscribeWithPayment(int creatorId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final url = '$_baseUrl/subscriptions/$creatorId/payment';
      print('🌐 [SubscriptionService] Calling subscribeWithPayment: $url'); // Debug
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] subscribeWithPayment status: ${response.statusCode}'); // Debug
      print('🔍 [SubscriptionService] subscribeWithPayment body: ${response.body}'); // Debug

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'client_secret': data['client_secret'],
        };
      } else if (response.statusCode == 400) {
        throw Exception(data['error'] ?? 'Vous êtes déjà abonné à ce créateur');
      } else if (response.statusCode == 401) {
        throw Exception('Session expirée, veuillez vous reconnecter');
      } else {
        throw Exception(data['error'] ?? 'Erreur lors de l\'abonnement avec paiement');
      }
    } catch (e) {
      print('❌ [SubscriptionService] subscribeWithPayment error: $e'); // Debug
      throw Exception('Erreur réseau: $e');
    }
  }

  /// S'abonner à un créateur sans paiement immédiat
  static Future<Map<String, dynamic>> subscribe(int creatorId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final url = '$_baseUrl/subscription/subscribe/$creatorId';
      print('🌐 [SubscriptionService] Calling subscribe: $url'); // Debug
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] subscribe status: ${response.statusCode}'); // Debug
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        throw Exception(data['error'] ?? 'Erreur lors de l\'abonnement');
      }
    } catch (e) {
      print('❌ [SubscriptionService] subscribe error: $e'); // Debug
      throw Exception('Erreur réseau: $e');
    }
  }

  /// Se désabonner d'un créateur
  static Future<Map<String, dynamic>> unsubscribe(int creatorId) async {
    try {
      final token = await AuthStorage.getToken();
      if (token == null) {
        throw Exception('Token d\'authentification manquant');
      }

      final url = '$_baseUrl/subscription/unsubscribe/$creatorId';
      print('🌐 [SubscriptionService] Calling unsubscribe: $url'); // Debug
      
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [SubscriptionService] unsubscribe status: ${response.statusCode}'); // Debug
      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
        };
      } else {
        throw Exception(data['error'] ?? 'Erreur lors du désabonnement');
      }
    } catch (e) {
      print('❌ [SubscriptionService] unsubscribe error: $e'); // Debug
      throw Exception('Erreur réseau: $e');
    }
  }
}