// lib/core/providers/profile_provider.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../features/auth/auth_provider.dart';
import '../models/profile_models.dart'; 
import '../services/profile_service.dart';
import '../../core/services/user_stats_service.dart'; 

/// Provider pour la gestion de l'état de la page profil
class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService = ProfileService();
  final AuthProvider _authProvider;

  // États de chargement
  bool _isLoadingStats = false;
  bool _isLoadingPosts = false;
  bool _isUploadingAvatar = false;
  bool _isUpdatingBio = false;
  bool _isCheckingUsername = false;

  // Données
  ProfileStats? _stats;
  UserStats? _subscriptionStats; // ✅ AJOUT: Stats d'abonnements
  List<UserPost> _userPosts = [];
  String _currentPostsType = 'all'; // 'all', 'public', 'subscriber'
  int _currentPage = 1;
  bool _hasMorePosts = true;

  // Erreurs
  String? _error;

  // 🔥 CORRECTION : Flag pour éviter les doubles chargements
  bool _isInitialized = false;

  ProfileProvider(this._authProvider) {
    // Écouter les changements d'authentification
    _authProvider.addListener(_onAuthChanged);
    
    // 🔥 SOLUTION : Chargement différé plus robuste
    if (_authProvider.isAuthenticated) {
      _scheduleInitialLoad();
    }
  }

  // ===== GETTERS =====
  bool get isLoadingStats => _isLoadingStats;
  bool get isLoadingPosts => _isLoadingPosts;
  bool get isUploadingAvatar => _isUploadingAvatar;
  bool get isUpdatingBio => _isUpdatingBio;
  bool get isCheckingUsername => _isCheckingUsername;
  bool get isLoading => _isLoadingStats || _isLoadingPosts;

  ProfileStats get stats => _stats ?? ProfileStats.empty();
  
  // ✅ AJOUT: Getters pour les stats d'abonnements intégrées
  UserStats get subscriptionStats => _subscriptionStats ?? UserStats(
    postsCount: stats.postsCount,
    followersCount: 0,
    followingCount: 0,
    likesReceived: stats.likesReceived,
    totalEarnings: stats.totalEarnings,
  );
  
  // ✅ AJOUT: Getters individuels pour l'affichage
  int get postsCount => _subscriptionStats?.postsCount ?? stats.postsCount;
  int get followersCount => _subscriptionStats?.followersCount ?? 0;
  int get followingCount => _subscriptionStats?.followingCount ?? 0;
  int get likesReceived => _subscriptionStats?.likesReceived ?? stats.likesReceived;
  double get totalEarnings => _subscriptionStats?.totalEarnings ?? stats.totalEarnings;
  
  List<UserPost> get userPosts => _userPosts;
  String get currentPostsType => _currentPostsType;
  bool get hasMorePosts => _hasMorePosts;
  String? get error => _error;
  bool get isInitialized => _isInitialized;

  // ===== MÉTHODES PUBLIQUES =====

  void ensureInitialized() {
    if (!_isInitialized && _authProvider.isAuthenticated) {
      // debugPrint('🔄 [ProfileProvider] Force initialization requested');
      _scheduleInitialLoad();
    }
  }

  /// Charge toutes les données du profil
  Future<void> loadProfileData() async {
    if (!_authProvider.isAuthenticated) return;
    
    // debugPrint('🔄 [ProfileProvider] Loading complete profile data');
    await _loadInitialData();
  }

  /// Rafraîchit toutes les données
  Future<void> refreshAllData() async {
    if (!_authProvider.isAuthenticated) return;
    
    // debugPrint('🔄 [ProfileProvider] Refreshing all profile data');
    _clearError();
    
    // ✅ MODIFICATION: Chargement parallèle des stats et des abonnements
    await Future.wait([
      _loadStats(),
      _loadSubscriptionStats(), // ✅ AJOUT
    ]);
    
    await _loadUserPosts(refresh: true);
    
    // Notification finale garantie
    _safeNotifyListeners();
  }

  /// Charge les statistiques du profil
  Future<void> loadStats() async {
    await _loadStats();
  }

  /// ✅ AJOUT: Charge spécifiquement les stats d'abonnements
  Future<void> loadSubscriptionStats() async {
    await _loadSubscriptionStats();
  }

  /// Charge les posts de l'utilisateur
  Future<void> loadUserPosts({bool refresh = false, String? type}) async {
    await _loadUserPosts(refresh: refresh, type: type);
  }

  /// Efface l'erreur courante
  void clearError() {
    _clearError();
  }

  // ===== MÉTHODES PRIVÉES =====

  void _scheduleInitialLoad() {
    // Triple délai pour s'assurer que tout est monté
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_authProvider.isAuthenticated && !_isInitialized) {
          // debugPrint('🚀 [ProfileProvider] Starting scheduled initial load');
          _loadInitialData();
        }
      });
    });
  }

  /// ✅ MODIFICATION: Chargement initial avec stats d'abonnements
  Future<void> _loadInitialData() async {
    if (!_authProvider.isAuthenticated || _isInitialized) return;

    // debugPrint('🔄 [ProfileProvider] Loading initial profile data');
    _isInitialized = true; // 🔥 Marquer comme initialisé
    
    try {
      // ✅ MODIFICATION: Chargement parallèle des stats (plus rapide)
      await Future.wait([
        _loadStats(),
        _loadSubscriptionStats(), // ✅ AJOUT
      ]);
      
      await _loadUserPosts(refresh: true);
      
      // debugPrint('✅ [ProfileProvider] Initial profile data loaded successfully');
      
    } catch (e) {
      debugPrint('❌ [ProfileProvider] Error in _loadInitialData: $e');
      _setError('Erreur lors du chargement initial');
    }
  }

  /// Charge les statistiques du profil
  Future<void> _loadStats() async {
    if (!_authProvider.isAuthenticated) return;
    
    _setLoadingStats(true);
    _clearError();
    
    try {
      final result = await _profileService.getProfileStats();
      
      if (result.isSuccess && result.data != null) {
        _stats = result.data;
        // debugPrint('📊 [ProfileProvider] Stats loaded: ${_stats.toString()}');
      } else {
        _setError(result.error?.message ?? 'Erreur de chargement des statistiques');
      }
    } catch (e) {
      _setError('Erreur inattendue lors du chargement des statistiques');
      debugPrint('❌ [ProfileProvider] Stats loading error: $e');
    } finally {
      _setLoadingStats(false);
    }
  }

  /// ✅ AJOUT: Charge les statistiques d'abonnements depuis l'API
  Future<void> _loadSubscriptionStats() async {
    if (!_authProvider.isAuthenticated) return;
    
    try {
      final user = _authProvider.user;
      if (user?.id == null) return;
      
      // debugPrint('📊 [ProfileProvider] Loading subscription stats');
      final subscriptionStats = await UserStatsService.getUserStats(user!.id);
      
      _subscriptionStats = subscriptionStats;
      // debugPrint('📊 [ProfileProvider] Subscription stats loaded: Posts:${subscriptionStats.postsCount}, Followers:${subscriptionStats.followersCount}, Following:${subscriptionStats.followingCount}');
      
      _safeNotifyListeners();
      
    } catch (e) {
      debugPrint('❌ [ProfileProvider] Subscription stats loading error: $e');
      // Ne pas définir d'erreur pour les stats d'abonnements pour ne pas bloquer l'UI
      // On garde les stats par défaut
    }
  }

  Future<void> _loadUserPosts({bool refresh = false, String? type}) async {
    if (!_authProvider.isAuthenticated) return;
    
    // debugPrint('📝 [ProfileProvider] Starting loadUserPosts (refresh: $refresh, type: $type)');
    
    // Si on refresh ou change de type, réinitialiser
    if (refresh || (type != null && type != _currentPostsType)) {
      _userPosts.clear();
      _currentPage = 1;
      _hasMorePosts = true;
      if (type != null) _currentPostsType = type;
    }
    
    // Si plus de posts disponibles, arrêter
    if (!_hasMorePosts) {
      // debugPrint('📝 [ProfileProvider] No more posts available');
      return;
    }
    
    _setLoadingPosts(true);
    if (refresh) _clearError();
    
    try {
      // debugPrint('📝 [ProfileProvider] Calling API for posts (page: $_currentPage, type: $_currentPostsType)');
      
      final result = await _profileService.getUserPosts(
        page: _currentPage,
        limit: 20,
        type: _currentPostsType,
      );
      
      if (result.isSuccess && result.data != null) {
        final newPosts = result.data!;
        // debugPrint('📝 [ProfileProvider] API returned ${newPosts.length} posts');
        
        if (refresh || _currentPage == 1) {
          _userPosts = newPosts;
          // debugPrint('📝 [ProfileProvider] Posts replaced (total: ${_userPosts.length})');
        } else {
          _userPosts.addAll(newPosts);
          // debugPrint('📝 [ProfileProvider] Posts added (total: ${_userPosts.length})');
        }
        
        // Vérifier s'il y a plus de posts
        _hasMorePosts = newPosts.length >= 20;
        _currentPage++;
        
        // debugPrint('📝 [ProfileProvider] Posts loaded successfully: ${newPosts.length} (total: ${_userPosts.length})');
        
      } else {
        debugPrint('❌ [ProfileProvider] Failed to load posts: ${result.error?.message}');
        _setError(result.error?.message ?? 'Erreur de chargement des posts');
      }
    } catch (e) {
      _setError('Erreur inattendue lors du chargement des posts');
      debugPrint('❌ [ProfileProvider] Posts loading error: $e');
    } finally {
      _setLoadingPosts(false);
      // 🔥 NOTIFICATION GARANTIE à la fin du chargement
      _safeNotifyListeners();
    }
  }

  /// Listener pour les changements d'authentification
  void _onAuthChanged() {
    if (_authProvider.isAuthenticated && !_isInitialized) {
      // debugPrint('👤 [ProfileProvider] User authenticated - scheduling profile data load');
      _scheduleInitialLoad();
    } else if (!_authProvider.isAuthenticated) {
      // debugPrint('👤 [ProfileProvider] User logged out - clearing profile data');
      _clearAllData();
    }
  }

  /// ✅ MODIFICATION: Efface toutes les données y compris les stats d'abonnements
  void _clearAllData() {
    _stats = null;
    _subscriptionStats = null; // ✅ AJOUT
    _userPosts.clear();
    _currentPage = 1;
    _hasMorePosts = true;
    _currentPostsType = 'all';
    _isInitialized = false; // 🔥 Reset du flag
    _clearError();
    _safeNotifyListeners();
  }

  /// 🔥 NOTIFICATION SÉCURISÉE : S'assure que la notification est bien envoyée
  void _safeNotifyListeners() {
    // Notification immédiate
    notifyListeners();
    
    // Notification différée pour s'assurer que l'UI reçoit le changement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
      debugPrint('🔔 [ProfileProvider] UI notification sent');
    });
  }

  /// Gestion des états de chargement
  void _setLoadingStats(bool loading) {
    if (_isLoadingStats != loading) {
      _isLoadingStats = loading;
      _safeNotifyListeners();
    }
  }

  void _setLoadingPosts(bool loading) {
    if (_isLoadingPosts != loading) {
      _isLoadingPosts = loading;
      _safeNotifyListeners();
    }
  }

  void _setUploadingAvatar(bool uploading) {
    if (_isUploadingAvatar != uploading) {
      _isUploadingAvatar = uploading;
      _safeNotifyListeners();
    }
  }

  void _setUpdatingBio(bool updating) {
    if (_isUpdatingBio != updating) {
      _isUpdatingBio = updating;
      _safeNotifyListeners();
    }
  }

  void _setCheckingUsername(bool checking) {
    if (_isCheckingUsername != checking) {
      _isCheckingUsername = checking;
      _safeNotifyListeners();
    }
  }

  void _setError(String? error) {
    if (_error != error) {
      _error = error;
      _safeNotifyListeners();
    }
  }

  void _clearError() {
    _setError(null);
  }

  @override
  void dispose() {
    _authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }

  // ===== MÉTHODES POUR LES AUTRES FONCTIONNALITÉS =====

  /// Upload d'avatar utilisateur
  Future<bool> uploadAvatar(File imageFile) async {
    if (!_authProvider.isAuthenticated) return false;
    
    _setUploadingAvatar(true);
    _clearError();
    
    try {
      debugPrint('📸 [ProfileProvider] Uploading avatar');
      
      final result = await _profileService.uploadAvatar(imageFile);
      
      if (result.isSuccess && result.data != null) {
        // debugPrint('📸 [ProfileProvider] Avatar uploaded successfully: ${result.data!.avatarUrl}');
        
        // Recharger le profil utilisateur pour obtenir la nouvelle URL
        await _authProvider.refreshProfile();
        
        return true;
      } else {
        // debugPrint('❌ [ProfileProvider] Failed to upload avatar: ${result.error?.message}');
        _setError(result.error?.message ?? 'Erreur lors de l\'upload de l\'avatar');
        return false;
      }
    } catch (e) {
      _setError('Erreur inattendue lors de l\'upload');
      debugPrint('❌ [ProfileProvider] Avatar upload error: $e');
      return false;
    } finally {
      _setUploadingAvatar(false);
    }
  }

  /// Mise à jour de la bio utilisateur
  Future<bool> updateBio(String newBio) async {
    if (!_authProvider.isAuthenticated) return false;
    
    _setUpdatingBio(true);
    _clearError();
    
    try {
      // debugPrint('📝 [ProfileProvider] Updating bio: $newBio');
      
      final result = await _profileService.updateBio(newBio);
      
      if (result.isSuccess) {
        // debugPrint('📝 [ProfileProvider] Bio updated successfully');
        
        // Recharger le profil utilisateur pour obtenir la nouvelle bio
        await _authProvider.refreshProfile();
        
        return true;
      } else {
        debugPrint('❌ [ProfileProvider] Failed to update bio: ${result.error?.message}');
        _setError(result.error?.message ?? 'Erreur lors de la mise à jour de la bio');
        return false;
      }
    } catch (e) {
      _setError('Erreur inattendue lors de la mise à jour');
      debugPrint('❌ [ProfileProvider] Bio update error: $e');
      return false;
    } finally {
      _setUpdatingBio(false);
    }
  }

  /// Vérification de disponibilité d'un username
  Future<bool?> checkUsernameAvailability(String username) async {
    if (!_authProvider.isAuthenticated) return null;
    
    _setCheckingUsername(true);
    
    try {
      final result = await _profileService.checkUsernameAvailability(username);
      
      if (result.isSuccess && result.data != null) {
        // debugPrint('🔍 [ProfileProvider] Username check: ${result.data!.username} available: ${result.data!.available}');
        return result.data!.available;
      } else {
        // debugPrint('❌ [ProfileProvider] Username check failed: ${result.error?.message}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ [ProfileProvider] Username check error: $e');
      return null;
    } finally {
      _setCheckingUsername(false);
    }
  }

  /// Plus de posts (pagination)
  Future<void> loadMorePosts() async {
    if (!_authProvider.isAuthenticated || !_hasMorePosts || _isLoadingPosts) {
      return;
    }
    
    // debugPrint('📝 [ProfileProvider] Loading more posts (page: $_currentPage)');
    await _loadUserPosts();
  }

  /// Changer le type de posts affiché
  Future<void> changePostsType(String type) async {
    if (type != _currentPostsType) {
      // debugPrint('📝 [ProfileProvider] Changing posts type to: $type');
      await _loadUserPosts(refresh: true, type: type);
    }
  }

  /// ✅ AJOUT: Méthode pour forcer le rechargement des stats d'abonnements
  Future<void> refreshSubscriptionStats() async {
    await _loadSubscriptionStats();
  }
}