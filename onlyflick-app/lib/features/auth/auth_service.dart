import 'package:flutter/foundation.dart';
import '../../../core/services/api_service.dart';
import 'models/auth_models.dart';

/// Service pour les opérations d'authentification avec le backend Go
class AuthService {
  final ApiService _apiService = ApiService();

  /// Connexion utilisateur avec sauvegarde de l'ID
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
        
        // : Sauvegarder l'ID utilisateur
        await _apiService.setCurrentUser(authData.userId);
        
        debugPrint('🔐 Login successful for user ID: ${authData.userId} (${authData.username})');
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

  /// Inscription utilisateur avec sauvegarde de l'ID
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
        
        // : Sauvegarder l'ID utilisateur
        await _apiService.setCurrentUser(authData.userId);
        
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

  /// Vérification de la disponibilité du username
  Future<UsernameCheckResult> checkUsernameAvailability(String username) async {
    try {
      debugPrint('🔐 Checking username availability: $username');
      
      final response = await _apiService.get<UsernameCheckResponse>(
        '/auth/check-username?username=${Uri.encodeComponent(username)}',
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
        '/profile',
        fromJson: (json) => User.fromJson(json),
      );

      if (response.isSuccess && response.data != null) {
        // debugPrint('🔐 Profile fetched successfully: ${response.data!.username}');
        return UserResult.success(response.data!);
      } else {
        debugPrint('❌ Failed to fetch profile: ${response.error}');
        
        // Si c'est une erreur d'auth, on déconnecte complètement
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

  /// Mise à jour du profil utilisateur
  Future<UserResult> updateProfile(UpdateProfileRequest request) async {
    try {
      debugPrint('🔐 Updating user profile');
      
      final response = await _apiService.patch<Map<String, dynamic>>(
        '/profile',
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
        '/profile/request-upgrade',
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
        '/profile',
      );

      if (response.isSuccess) {
        debugPrint('🔐 Account deleted successfully');
        
        // ✅ MODIFIÉ: Utiliser la méthode logout complète
        await logout();
        
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

  /// : Déconnexion complète (token + ID utilisateur)
  Future<void> logout() async {
    try {
      debugPrint('🔐 Logging out user...');
      
      // Optionnel: Appeler endpoint de logout sur le serveur
      try {
        await _apiService.post('/logout');
        debugPrint('🔐 Server logout successful');
      } catch (e) {
        debugPrint('⚠️ Server logout failed (non-critical): $e');
        // Ne pas faire échouer la déconnexion locale pour autant
      }
      
      // Nettoyer la session locale (token + ID utilisateur)
      await _apiService.logout();
      
      debugPrint('🔐 Complete logout successful');
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      // Même en cas d'erreur, forcer le nettoyage local
      await _apiService.logout();
    }
  }

  /// : Vérification complète de la session
  Future<bool> isLoggedIn() async {
    // Vérifier d'abord les données locales
    if (!_apiService.isAuthenticated) {
      debugPrint('🔐 No valid local session');
      return false;
    }

    // Vérifier avec le serveur que la session est toujours valide
    try {
      debugPrint('🔐 Validating session with server...');
      final result = await getProfile();
      
      if (result.isSuccess) {
        debugPrint('🔐 Session is valid for user ${_apiService.currentUserId}');
        return true;
      } else {
        debugPrint('🔐 Session expired, cleaning up...');
        await logout();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Session validation failed: $e');
      await logout();
      return false;
    }
  }

  /// ✅ AMÉLIORÉ: Vérification de session au démarrage de l'app
  Future<bool> checkSession() async {
    try {
      debugPrint('🔐 Checking session at app startup...');
      
      // Si pas de session locale, pas besoin de vérifier
      if (!_apiService.isAuthenticated) {
        debugPrint('🔐 No local session found');
        return false;
      }

      // Vérifier que la session est toujours valide
      final isValid = await isLoggedIn();
      
      if (isValid) {
        debugPrint('🔐 Session check successful for user ${_apiService.currentUserId}');
      } else {
        debugPrint('🔐 Session check failed, user logged out');
      }
      
      return isValid;
    } catch (e) {
      debugPrint('❌ Session check error: $e');
      await logout();
      return false;
    }
  }

  /// : Rafraîchissement du token (si supporté par votre backend)
  Future<bool> refreshToken() async {
    try {
      debugPrint('🔐 Attempting to refresh token...');
      
      final response = await _apiService.post<Map<String, dynamic>>(
        '/auth/refresh-token',
      );
      
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        
        if (data['token'] != null) {
          final newToken = data['token'] as String;
          await _apiService.setToken(newToken);
          
          // Si un nouvel ID utilisateur est fourni, le mettre à jour
          if (data['user_id'] != null) {
            final userId = data['user_id'] as int;
            await _apiService.setCurrentUser(userId);
          }
          
          debugPrint('🔐 Token refreshed successfully');
          return true;
        }
      }
      
      debugPrint('❌ Token refresh failed');
      await logout();
      return false;
    } catch (e) {
      debugPrint('❌ Token refresh error: $e');
      await logout();
      return false;
    }
  }

  /// : Getters pour les informations de session
  
  /// Vérifie si un token est stocké localement
  bool hasToken() => _apiService.hasToken;
  
  /// Vérifie si un ID utilisateur est stocké localement
  bool hasCurrentUser() => _apiService.hasCurrentUser;
  
  /// Vérifie si la session est complète (token + ID)
  bool get isAuthenticated => _apiService.isAuthenticated;
  
  /// Obtient l'ID de l'utilisateur connecté
  int? get currentUserId => _apiService.currentUserId;
  
  /// Obtient les informations complètes de session
  Map<String, dynamic> get sessionInfo => _apiService.sessionInfo;

  /// : Gestion des erreurs d'authentification
  void _handleAuthError() {
    debugPrint('⚠️ Authentication error detected, logging out...');
    logout();
  }

  /// : Validation d'email (utilitaire)
  bool isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email);
  }

  /// : Validation de mot de passe (utilitaire)
  bool isValidPassword(String password) {
    // Au moins 8 caractères
    return password.length >= 8;
  }

  /// : Validation d'username (utilitaire)
  bool isValidUsername(String username) {
    // Entre 3 et 20 caractères, lettres, chiffres, tiret et underscore
    return RegExp(r'^[a-zA-Z0-9_-]{3,20}$').hasMatch(username);
  }

  /// : Méthode pour obtenir l'état complet de l'authentification
  Future<AuthenticationState> getAuthenticationState() async {
    if (!isAuthenticated) {
      return AuthenticationState.notAuthenticated;
    }

    try {
      // Vérifier la validité avec le serveur
      final profileResult = await getProfile();
      
      if (profileResult.isSuccess) {
        return AuthenticationState.authenticated;
      } else {
        return AuthenticationState.expired;
      }
    } catch (e) {
      debugPrint('❌ Error checking authentication state: $e');
      return AuthenticationState.error;
    }
  }

  /// : Nettoyage des ressources
  void dispose() {
    // Si vous avez des streams ou timers à nettoyer
    debugPrint('🔐 AuthService disposed');
  }
}

/// : Énumération pour l'état d'authentification
enum AuthenticationState {
  notAuthenticated,  // Pas de session locale
  authenticated,     // Session valide
  expired,          // Session expirée
  error,            // Erreur de vérification
}

/// : Extension pour des méthodes utilitaires
extension AuthenticationStateExtension on AuthenticationState {
  bool get isAuthenticated => this == AuthenticationState.authenticated;
  bool get needsLogin => this == AuthenticationState.notAuthenticated || this == AuthenticationState.expired;
  bool get hasError => this == AuthenticationState.error;
  
  String get description {
    switch (this) {
      case AuthenticationState.notAuthenticated:
        return 'Non connecté';
      case AuthenticationState.authenticated:
        return 'Connecté';
      case AuthenticationState.expired:
        return 'Session expirée';
      case AuthenticationState.error:
        return 'Erreur d\'authentification';
    }
  }
}