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

  /// S'abonner avec paiement Stripe immédiat
  Future<UserServiceResult<Map<String, dynamic>>> subscribeWithPayment(int creatorId) async {
    try {
      debugPrint('💳 Subscribing with payment to creator $creatorId');
      
      final response = await _apiService.post('/subscriptions/$creatorId/payment');

      if (response.isSuccess && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('✅ Payment subscription initiated for creator $creatorId');
        return UserServiceResult.success(data);
      } else {
        debugPrint('❌ Failed to initiate payment subscription: ${response.error}');
        return UserServiceResult.failure(
          UserServiceError.fromApiResponse(
            response.error ?? 'Erreur lors du paiement de l\'abonnement',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error in subscribeWithPayment: $e');
      return UserServiceResult.failure(UserServiceError.network());
    }
  }

  /// Récupère la liste des abonnements de l'utilisateur connecté
  Future<UserServiceResult<List<Subscription>>> getMySubscriptions() async {
    try {
      debugPrint('📋 Fetching my subscriptions');
      
      // Utilisation d'une approche plus simple sans type générique complexe
      final response = await _apiService.get(
        '/subscriptions',
      );

      if (response.isSuccess && response.data != null) {
        // Parser manuellement les données
        List<Subscription> subscriptions = [];
        
        if (response.data is List) {
          final dataList = response.data as List;
          subscriptions = dataList
              .map((item) => Subscription.fromJson(item as Map<String, dynamic>))
              .toList();
        }
        
        debugPrint('✅ My subscriptions fetched: ${subscriptions.length} subscriptions');
        return UserServiceResult.success(subscriptions);
      } else {
        debugPrint('❌ Failed to fetch my subscriptions: ${response.error}');
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

/// Classe de résultat pour les opérations du UserService
class UserServiceResult<T> {
  final T? data;
  final UserServiceError? error;
  final bool isSuccess;

  const UserServiceResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory UserServiceResult.success(T data) {
    return UserServiceResult._(
      data: data,
      isSuccess: true,
    );
  }

  factory UserServiceResult.failure(UserServiceError error) {
    return UserServiceResult._(
      error: error,
      isSuccess: false,
    );
  }

  bool get isFailure => !isSuccess;
}

/// Classe d'erreur pour le UserService
class UserServiceError {
  final String message;
  final int? statusCode;
  final String type;

  const UserServiceError({
    required this.message,
    this.statusCode,
    required this.type,
  });

  factory UserServiceError.network() {
    return const UserServiceError(
      message: 'Erreur de connexion réseau',
      type: 'network',
    );
  }

  factory UserServiceError.fromApiResponse(String message, int? statusCode) {
    String type = 'api';
    
    if (statusCode != null) {
      switch (statusCode) {
        case 401:
          type = 'unauthorized';
          break;
        case 403:
          type = 'forbidden';
          break;
        case 404:
          type = 'not_found';
          break;
        case 500:
          type = 'server_error';
          break;
      }
    }

    return UserServiceError(
      message: message,
      statusCode: statusCode,
      type: type,
    );
  }

  bool get isNetworkError => type == 'network';
  bool get isUnauthorized => type == 'unauthorized';
  bool get isForbidden => type == 'forbidden';
  bool get isNotFound => type == 'not_found';
  bool get isServerError => type == 'server_error';

  @override
  String toString() => 'UserServiceError(message: $message, type: $type, statusCode: $statusCode)';
}