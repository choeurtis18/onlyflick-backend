import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import 'models/auth_models.dart';

/// Service pour les opérations d'authentification avec le backend Go
class AuthService {
  final ApiService _apiService = ApiService();

  /// Connexion utilisateur
  Future<AuthResult> login(LoginRequest request) async {
    try {
      debugPrint('🔐 Attempting login for: ${request.email}');
      
      final response = await _apiService.post<AuthResponse>(
        '/login',  // Endpoint de votre backend Go
        body: request.toJson(),
        fromJson: (json) => AuthResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        final authData = response.data!;
        
        // Sauvegarder le token automatiquement
        await _apiService.setToken(authData.token);
        
        debugPrint('🔐 Login successful for user ID: ${authData.userId}');
        return AuthResult.success(authData);
      } else {
        debugPrint('❌ Login failed: ${response.error}');
        return AuthResult.failure(
          AuthError.fromApiResponse(
            response.error ?? 'Erreur de connexion',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      return AuthResult.failure(AuthError.network());
    }
  }

  /// Inscription utilisateur AVEC USERNAME
  Future<AuthResult> register(RegisterRequest request) async {
    try {
      debugPrint('🔐 Attempting registration for: ${request.email} with username: ${request.username}');
      
      final response = await _apiService.post<AuthResponse>(
        '/register',  // Endpoint de votre backend Go
        body: request.toJson(),
        fromJson: (json) => AuthResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        final authData = response.data!;
        
        // Sauvegarder le token automatiquement
        await _apiService.setToken(authData.token);
        
        debugPrint('🔐 Registration successful for user ID: ${authData.userId}, username: ${authData.username}');
        return AuthResult.success(authData);
      } else {
        debugPrint('❌ Registration failed: ${response.error}');
        return AuthResult.failure(
          AuthError.fromApiResponse(
            response.error ?? 'Erreur d\'inscription',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      return AuthResult.failure(AuthError.network());
    }
  }

  /// ===== VÉRIFICATION DISPONIBILITÉ USERNAME =====
  Future<UsernameCheckResult> checkUsernameAvailability(String username) async {
    try {
      debugPrint('🔐 Checking username availability: $username');
      
      final response = await _apiService.get<UsernameCheckResponse>(
        '/auth/check-username?username=${Uri.encodeComponent(username)}',  // Route corrigée
        fromJson: (json) => UsernameCheckResponse.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('🔐 Username check successful: ${response.data!.available}');
        return UsernameCheckResult.success(response.data!);
      } else {
        debugPrint('❌ Username check failed: ${response.error}');
        return UsernameCheckResult.failure(
          AuthError.fromApiResponse(
            response.error ?? 'Erreur de vérification du username',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Username check error: $e');
      return UsernameCheckResult.failure(AuthError.network());
    }
  }

  /// Récupération du profil utilisateur
  Future<UserResult> getProfile() async {
    try {
      debugPrint('🔐 Fetching user profile');
      
      final response = await _apiService.get<User>(
        '/profile',  // Endpoint de votre backend Go
        fromJson: (json) => User.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        debugPrint('🔐 Profile fetched successfully: ${response.data!.username}');
        return UserResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to fetch profile: ${response.error}');
        
        // Si c'est une erreur d'auth, on déconnecte
        if (response.isAuthError) {
          await logout();
        }
        
        return UserResult.failure(
          AuthError.fromApiResponse(
            response.error ?? 'Erreur de récupération du profil',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Profile fetch error: $e');
      return UserResult.failure(AuthError.network());
    }
  }

  /// Mise à jour du profil utilisateur (AVEC SUPPORT USERNAME)
  Future<UserResult> updateProfile(UpdateProfileRequest request) async {
    try {
      debugPrint('🔐 Updating user profile');
      
      final response = await _apiService.patch<Map<String, dynamic>>(
        '/profile',  // Endpoint de votre backend Go
        body: request.toJson(),
      );

      if (response.isSuccess) {
        debugPrint('🔐 Profile updated successfully');
        
        // Récupérer le profil mis à jour
        return await getProfile();
      } else {
        debugPrint('❌ Failed to update profile: ${response.error}');
        return UserResult.failure(
          AuthError.fromApiResponse(
            response.error ?? 'Erreur de mise à jour du profil',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Profile update error: $e');
      return UserResult.failure(AuthError.network());
    }
  }

  /// Demande de passage en créateur
  Future<AuthResult> requestCreatorUpgrade() async {
    try {
      debugPrint('🔐 Requesting creator upgrade');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        '/profile/request-upgrade',  // Endpoint de votre backend Go
      );

      if (response.isSuccess) {
        debugPrint('🔐 Creator upgrade request sent successfully');
        return AuthResult.success(null);
      } else {
        debugPrint('❌ Failed to request creator upgrade: ${response.error}');
        return AuthResult.failure(
          AuthError.fromApiResponse(
            response.error ?? 'Erreur de demande de passage en créateur',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Creator upgrade request error: $e');
      return AuthResult.failure(AuthError.network());
    }
  }

  /// Suppression du compte
  Future<AuthResult> deleteAccount() async {
    try {
      debugPrint('🔐 Deleting user account');
      
      final response = await _apiService.delete<Map<String, dynamic>>(
        '/profile',  // Endpoint de votre backend Go
      );

      if (response.isSuccess) {
        debugPrint('🔐 Account deleted successfully');
        
        // Supprimer le token
        await _apiService.setToken(null);
        
        return AuthResult.success(null);
      } else {
        debugPrint('❌ Failed to delete account: ${response.error}');
        return AuthResult.failure(
          AuthError.fromApiResponse(
            response.error ?? 'Erreur de suppression du compte',
            response.statusCode,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Account deletion error: $e');
      return AuthResult.failure(AuthError.network());
    }
  }

  /// Déconnexion utilisateur
  Future<void> logout() async {
    debugPrint('🔐 Logging out user');
    
    // Supprimer le token localement
    await _apiService.setToken(null);
    
    debugPrint('🔐 User logged out');
  }

  /// Vérification de l'état de connexion
  Future<bool> isLoggedIn() async {
    final token = _apiService.token;
    if (token == null) {
      return false;
    }

    // Vérifier la validité du token avec le serveur
    try {
      final result = await getProfile();
      return result.isSuccess;
    } catch (e) {
      debugPrint('❌ Token validation failed: $e');
      return false;
    }
  }

  /// Vérifie si un token est stocké localement
  bool hasToken() {
    return _apiService.token != null;
  }
}