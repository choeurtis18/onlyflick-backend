// lib/core/services/user_service.dart
import 'package:flutter/foundation.dart';
import '../../core/services/api_service.dart';
import '../../features/auth/models/auth_models.dart' as auth_models;
import '../models/user_models.dart';

/// Service pour la gestion des utilisateurs et abonnements
class UserService {
  final ApiService _apiService = ApiService();

  /// Récupère le profil public d'un utilisateur
  Future<UserServiceResult<PublicUserProfile>> getUserProfile(int userId) async {
    try {
      debugPrint('🔍 Fetching public profile for user $userId');
      
      final response = await _apiService.get('/users/$userId');

      if (response.isSuccess && response.data != null) {
        final profile = PublicUserProfile.fromJson(response.data as Map<String, dynamic>);
        debugPrint('✅ Public profile fetched successfully for user $userId');
        return UserServiceResult.success(profile);
      } else {
        debugPrint('❌ Failed to fetch public profile: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors de la récupération du profil',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in getUserProfile: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// ===== NOUVEAU : Récupère les posts d'un utilisateur =====
  Future<UserServiceResult<UserPostsResponse>> getUserPosts(
    int userId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      debugPrint('🔍 Fetching posts for user $userId (page: $page, limit: $limit)');
      
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      final response = await _apiService.get(
        '/users/$userId/posts',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        // L'API retourne un objet avec 'data' qui contient les posts
        final responseData = response.data as Map<String, dynamic>;
        final postsData = responseData['data'] as Map<String, dynamic>;
        
        final postsResponse = UserPostsResponse.fromJson(postsData);
        debugPrint('✅ Posts fetched successfully: ${postsResponse.posts.length} posts for user $userId');
        return UserServiceResult.success(postsResponse);
      } else {
        debugPrint('❌ Failed to fetch user posts: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors de la récupération des posts',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in getUserPosts: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// Recherche des utilisateurs par nom d'utilisateur
  Future<UserServiceResult<UserSearchResponse>> searchUsers({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      debugPrint('🔍 Searching users with query: "$query"');
      
      final queryParams = {
        'q': query,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      final response = await _apiService.get(
        '/search/users',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        final searchResponse = UserSearchResponse.fromJson(response.data as Map<String, dynamic>);
        debugPrint('✅ User search successful: ${searchResponse.users.length} users found');
        return UserServiceResult.success(searchResponse);
      } else {
        debugPrint('❌ Failed to search users: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors de la recherche',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in searchUsers: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// Vérifie le statut d'abonnement à un créateur
  Future<UserServiceResult<SubscriptionStatus>> checkSubscriptionStatus(int creatorId) async {
    try {
      debugPrint('🔍 Checking subscription status for creator $creatorId');
      
      final response = await _apiService.get('/subscriptions/$creatorId/status');

      if (response.isSuccess && response.data != null) {
        final status = SubscriptionStatus.fromJson(response.data as Map<String, dynamic>);
        debugPrint('✅ Subscription status fetched: ${status.status}');
        return UserServiceResult.success(status);
      } else {
        debugPrint('❌ Failed to check subscription status: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors de la vérification de l\'abonnement',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in checkSubscriptionStatus: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// S'abonner à un créateur (sans paiement immédiat)
  Future<UserServiceResult<String>> subscribeToCreator(int creatorId) async {
    try {
      debugPrint('🔔 Subscribing to creator $creatorId');
      
      final response = await _apiService.post('/subscriptions/$creatorId');

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final message = data['message']?.toString() ?? 'Abonnement réussi';
        debugPrint('✅ Successfully subscribed to creator $creatorId');
        return UserServiceResult.success(message);
      } else {
        debugPrint('❌ Failed to subscribe: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors de l\'abonnement',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in subscribeToCreator: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// Se désabonner d'un créateur
  Future<UserServiceResult<String>> unsubscribeFromCreator(int creatorId) async {
    try {
      debugPrint('🔕 Unsubscribing from creator $creatorId');
      
      final response = await _apiService.delete('/subscriptions/$creatorId');

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final message = data['message']?.toString() ?? 'Désabonnement réussi';
        debugPrint('✅ Successfully unsubscribed from creator $creatorId');
        return UserServiceResult.success(message);
      } else {
        debugPrint('❌ Failed to unsubscribe: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors du désabonnement',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in unsubscribeFromCreator: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// S'abonner à un créateur avec paiement
  Future<UserServiceResult<Map<String, dynamic>>> subscribeWithPayment(int creatorId) async {
    try {
      debugPrint('💳 Subscribing to creator $creatorId with payment');
      
      final response = await _apiService.post('/subscriptions/$creatorId/payment');

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('✅ Payment subscription initiated for creator $creatorId');
        return UserServiceResult.success(data);
      } else {
        debugPrint('❌ Failed to subscribe with payment: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors de l\'abonnement avec paiement',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in subscribeWithPayment: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// Obtenir la liste des abonnements de l'utilisateur
  Future<UserServiceResult<List<Subscription>>> getMySubscriptions() async {
    try {
      debugPrint('🔍 Fetching my subscriptions');
      
      final response = await _apiService.get('/subscriptions/');

      if (response.isSuccess && response.data != null) {
        final data = response.data as List<dynamic>;
        final subscriptions = data
            .map((sub) => Subscription.fromJson(sub as Map<String, dynamic>))
            .toList();
        debugPrint('✅ Subscriptions fetched: ${subscriptions.length} subscriptions');
        return UserServiceResult.success(subscriptions);
      } else {
        debugPrint('❌ Failed to fetch subscriptions: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors de la récupération des abonnements',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in getMySubscriptions: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }
}

/// ===== RÉSULTATS D'OPÉRATIONS =====

/// Résultat générique pour les opérations du UserService
class UserServiceResult<T> {
  final bool isSuccess;
  final T? data;
  final UserServiceError? error;

  const UserServiceResult._({
    required this.isSuccess,
    this.data,
    this.error,
  });

  factory UserServiceResult.success(T data) {
    return UserServiceResult._(isSuccess: true, data: data);
  }

  factory UserServiceResult.failure(UserServiceError error) {
    return UserServiceResult._(isSuccess: false, error: error);
  }

  bool get isFailure => !isSuccess;

  @override
  String toString() => isSuccess 
      ? 'UserServiceResult.success($data)' 
      : 'UserServiceResult.failure($error)';
}

/// Erreur du UserService
class UserServiceError {
  final String message;
  final int? statusCode;
  final String? field;

  const UserServiceError({
    required this.message,
    this.statusCode,
    this.field,
  });

  factory UserServiceError.network() {
    return const UserServiceError(
      message: 'Erreur réseau. Vérifiez votre connexion internet.',
    );
  }

  factory UserServiceError.fromApiResponse(String message, int? statusCode) {
    return UserServiceError(
      message: message,
      statusCode: statusCode,
    );
  }

  factory UserServiceError.validation(String field, String message) {
    return UserServiceError(
      message: message,
      field: field,
    );
  }

  @override
  String toString() => 'UserServiceError(message: $message, statusCode: $statusCode)';
}