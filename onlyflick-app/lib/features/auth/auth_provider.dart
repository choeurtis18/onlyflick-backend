import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './auth_service.dart';
import 'models/auth_models.dart';
import '../../core/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  // État d'authentification
  AuthState _state = AuthState.initial;
  User? _user;
  AuthError? _error;

  // ===== ÉTAT VÉRIFICATION USERNAME =====
  bool _isCheckingUsername = false;
  UsernameCheckResult? _lastUsernameCheck;

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  AuthError? get error => _error;
  
  bool get isLoading => _state == AuthState.loading;
  bool get isAuthenticated => _state == AuthState.authenticated && _user != null;
  bool get isUnauthenticated => _state == AuthState.unauthenticated;
  bool get hasError => _state == AuthState.error && _error != null;

  // ===== GETTERS USERNAME =====
  bool get isCheckingUsername => _isCheckingUsername;
  UsernameCheckResult? get lastUsernameCheck => _lastUsernameCheck;

  // Getters de rôle
  bool get isCreator => _user?.isCreator ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isSubscriber => _user?.isSubscriber ?? false;

  /// Initialise le provider et vérifie l'état d'authentification
  Future<void> checkAuth() async {
    // debugPrint('🔐 Checking authentication state...');
    
    try {
      // Initialiser l'API service
      await _apiService.initialize();
      
      // Vérifier si un token existe et est valide
      if (_authService.hasToken()) {
        _setState(AuthState.loading);
        
        final result = await _authService.getProfile();
        if (result.isSuccess && result.data != null) {
          _user = result.data;
          _setState(AuthState.authenticated);
          debugPrint('🔐 User authenticated: ${_user!.email} (@${_user!.username})');
        } else {
          _setState(AuthState.unauthenticated);
          debugPrint('🔐 Token invalid, user unauthenticated');
        }
      } else {
        _setState(AuthState.unauthenticated);
        debugPrint('🔐 No token found, user unauthenticated');
      }
    } catch (e) {
      debugPrint('❌ Auth check error: $e');
      _setState(AuthState.unauthenticated);
    }
  }

  /// Connexion utilisateur
  Future<bool> login(String email, String password) async {
    debugPrint('🔐 Login attempt for: $email');
    
    _setState(AuthState.loading);
    _clearError();

    try {
      final request = LoginRequest(email: email, password: password);
      final result = await _authService.login(request);

      if (result.isSuccess) {
        // Récupérer le profil utilisateur
        final profileResult = await _authService.getProfile();
        
        if (profileResult.isSuccess && profileResult.data != null) {
          _user = profileResult.data;
          _setState(AuthState.authenticated);
          debugPrint('🔐 Login successful for: ${_user!.email} (@${_user!.username})');
          return true;
        } else {
          _setError(profileResult.error ?? AuthError.server());
          return false;
        }
      } else {
        _setError(result.error ?? AuthError.server());
        return false;
      }
    } catch (e) {
      debugPrint('❌ Login error: $e');
      _setError(AuthError.network());
      return false;
    }
  }

  /// Inscription utilisateur AVEC USERNAME
  Future<bool> register(String firstName, String lastName, String username, String email, String password) async {
    debugPrint('🔐 Registration attempt for: $email with username: $username');
    
    _setState(AuthState.loading);
    _clearError();

    try {
      final request = RegisterRequest(
        firstName: firstName,
        lastName: lastName,
        username: username,  // ===== AJOUT USERNAME =====
        email: email,
        password: password,
      );

      // ===== VALIDATION CÔTÉ CLIENT =====
      final validationErrors = request.validate();
      if (validationErrors.isNotEmpty) {
        _setError(AuthError.validation('form', validationErrors.first));
        return false;
      }
      
      final result = await _authService.register(request);

      if (result.isSuccess) {
        // Récupérer le profil utilisateur
        final profileResult = await _authService.getProfile();
        
        if (profileResult.isSuccess && profileResult.data != null) {
          _user = profileResult.data;
          _setState(AuthState.authenticated);
          debugPrint('🔐 Registration successful for: ${_user!.email} (@${_user!.username})');
          return true;
        } else {
          _setError(profileResult.error ?? AuthError.server());
          return false;
        }
      } else {
        _setError(result.error ?? AuthError.server());
        return false;
      }
    } catch (e) {
      debugPrint('❌ Registration error: $e');
      _setError(AuthError.network());
      return false;
    }
  }

  /// ===== NOUVELLE MÉTHODE : Vérification disponibilité username =====
  Future<bool> checkUsernameAvailability(String username) async {
    debugPrint('🔐 Checking username availability: $username');
    
    // Ne pas vérifier si username vide
    if (username.trim().isEmpty) {
      _lastUsernameCheck = null;
      notifyListeners();
      return false;
    }

    _isCheckingUsername = true;
    notifyListeners();

    try {
      final result = await _authService.checkUsernameAvailability(username);
      
      _lastUsernameCheck = result;
      _isCheckingUsername = false;
      notifyListeners();

      if (result.isSuccess) {
        debugPrint('🔐 Username $username availability: ${result.data?.available}');
        return result.data?.available ?? false;
      } else {
        debugPrint('❌ Username check error: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Username check error: $e');
      _lastUsernameCheck = UsernameCheckResult.failure(AuthError.network());
      _isCheckingUsername = false;
      notifyListeners();
      return false;
    }
  }

  /// Efface le dernier résultat de vérification username
  void clearUsernameCheck() {
    _lastUsernameCheck = null;
    _isCheckingUsername = false;
    notifyListeners();
  }

  /// Mise à jour du profil utilisateur AVEC SUPPORT USERNAME
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? password,
    String? username,  // ===== AJOUT USERNAME =====
    String? avatarUrl,
    String? bio,
  }) async {
    if (!isAuthenticated) return false;
    
    debugPrint('🔐 Updating profile for: ${_user!.email}');
    
    _setState(AuthState.loading);
    _clearError();

    try {
      final request = UpdateProfileRequest(
        firstName: firstName,
        lastName: lastName,
        email: email,
        password: password,
        username: username,  // ===== SUPPORT USERNAME =====
        avatarUrl: avatarUrl,
        bio: bio,
      );
      
      final result = await _authService.updateProfile(request);

      if (result.isSuccess && result.data != null) {
        _user = result.data;
        _setState(AuthState.authenticated);
        debugPrint('🔐 Profile updated successfully for: ${_user!.email} (@${_user!.username})');
        return true;
      } else {
        _setError(result.error ?? AuthError.server());
        return false;
      }
    } catch (e) {
      debugPrint('❌ Profile update error: $e');
      _setError(AuthError.network());
      return false;
    }
  }

  /// ===== MÉTHODES SPÉCIALISÉES POUR MISE À JOUR RAPIDE =====
  
  /// Mise à jour username uniquement
  Future<bool> updateUsername(String newUsername) async {
    return await updateProfile(username: newUsername);
  }

  /// Mise à jour bio uniquement
  Future<bool> updateBio(String newBio) async {
    return await updateProfile(bio: newBio);
  }

  /// Mise à jour avatar uniquement
  Future<bool> updateAvatar(String newAvatarUrl) async {
    return await updateProfile(avatarUrl: newAvatarUrl);
  }

  /// Demande de passage en créateur
  Future<bool> requestCreatorUpgrade() async {
    if (!isAuthenticated) return false;
    
    debugPrint('🔐 Requesting creator upgrade for: ${_user!.email}');
    
    _setState(AuthState.loading);
    _clearError();

    try {
      final result = await _authService.requestCreatorUpgrade();

      if (result.isSuccess) {
        // Recharger le profil pour voir si le statut a changé
        await _refreshProfile();
        debugPrint('🔐 Creator upgrade request sent successfully');
        return true;
      } else {
        _setError(result.error ?? AuthError.server());
        return false;
      }
    } catch (e) {
      debugPrint('❌ Creator upgrade request error: $e');
      _setError(AuthError.network());
      return false;
    }
  }

  /// Suppression du compte
  Future<bool> deleteAccount() async {
    if (!isAuthenticated) return false;
    
    debugPrint('🔐 Deleting account for: ${_user!.email}');
    
    _setState(AuthState.loading);
    _clearError();

    try {
      final result = await _authService.deleteAccount();

      if (result.isSuccess) {
        _user = null;
        _setState(AuthState.unauthenticated);
        debugPrint('🔐 Account deleted successfully');
        return true;
      } else {
        _setError(result.error ?? AuthError.server());
        return false;
      }
    } catch (e) {
      debugPrint('❌ Account deletion error: $e');
      _setError(AuthError.network());
      return false;
    }
  }

  /// Déconnexion utilisateur
  Future<void> logout() async {
    debugPrint('🔐 Logging out user: ${_user?.email}');
    
    await _authService.logout();
    _user = null;
    _lastUsernameCheck = null;  // ===== EFFACER CACHE USERNAME =====
    _isCheckingUsername = false;
    _setState(AuthState.unauthenticated);
    _clearError();
    
    debugPrint('🔐 User logged out successfully');
  }

  /// Actualise le profil utilisateur
  Future<void> refreshProfile() async {
    await _refreshProfile();
  }

  /// Actualise le profil utilisateur (méthode privée)
  Future<void> _refreshProfile() async {
    if (!isAuthenticated) return;
    
    try {
      final result = await _authService.getProfile();
      
      if (result.isSuccess && result.data != null) {
        _user = result.data;
        _setState(AuthState.authenticated);
        debugPrint('🔐 Profile refreshed for: ${_user!.email} (@${_user!.username})');
      } else if (result.error?.statusCode == 401) {
        // Si erreur d'auth, déconnecter
        await logout();
      }
    } catch (e) {
      debugPrint('❌ Profile refresh error: $e');
    }
  }

  /// Change l'état et notifie les listeners
  void _setState(AuthState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Définit une erreur et change l'état
  void _setError(AuthError authError) {
    _error = authError;
    _setState(AuthState.error);
  }

  /// Efface l'erreur
  void _clearError() {
    _error = null;
  }

  /// ===== MÉTHODES UTILITAIRES POUR UI =====
  
  /// Obtient le nom d'affichage de l'utilisateur connecté
  String get displayName {
    if (_user == null) return '';
    return _user!.displayName;
  }

  /// Obtient le nom complet de l'utilisateur connecté
  String get fullName {
    if (_user == null) return '';
    return _user!.fullName;
  }

  /// Obtient le username de l'utilisateur connecté
  String get username {
    if (_user == null) return '';
    return _user!.username;
  }

  /// Vérifie si le username actuel est valide
  bool isUsernameValid(String username) {
    final request = RegisterRequest(
      firstName: 'temp',
      lastName: 'temp', 
      username: username,
      email: 'temp@temp.com',
      password: 'temp123',
    );
    return request.validateUsername() == null;
  }

  /// Méthode pour vérifier si l'utilisateur est connecté (legacy)
  Future<bool> isLoggedIn() async {
    return isAuthenticated;
  }

  /// Méthode pour définir l'état connecté (legacy)
  Future<void> setLoggedIn(bool value) async {
    if (value && !isAuthenticated) {
      await checkAuth();
    } else if (!value && isAuthenticated) {
      await logout();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}