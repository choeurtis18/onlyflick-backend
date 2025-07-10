// lib/core/providers/search_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/search_models.dart';
import '../services/search_service.dart';

/// États possibles pour la recherche
enum SearchState {
  initial,
  loading,
  loaded,
  error,
  loadingMore,
}

/// Provider pour la recherche d'utilisateurs et de posts
class SearchProvider with ChangeNotifier {
  final SearchService _searchService = SearchService();

  //  ÉTAT DE LA RECHERCHE UTILISATEURS 
  SearchState _searchState = SearchState.initial;
  SearchResult _searchResult = const SearchResult(posts: [], users: [], total: 0, hasMore: false);
  String? _searchError;
  String _currentQuery = '';
  
  //  ÉTAT DE LA RECHERCHE POSTS 
  bool _isSearchingPosts = false;
  List<PostWithDetails> _searchedPosts = [];
  String? _postsError;
  
  //  PAGINATION 
  static const int _pageSize = 20;
  int _searchOffset = 0;

  //  GETTERS UTILISATEURS 
  SearchState get searchState => _searchState;
  SearchResult get searchResult => _searchResult;
  String? get searchError => _searchError;
  String get currentQuery => _currentQuery;
  bool get isLoading => _searchState == SearchState.loading;
  bool get isLoadingMoreSearch => _searchState == SearchState.loadingMore;
  bool get hasSearchResults => _searchResult.users.isNotEmpty;
  List<UserSearchResult> get searchedUsers => _searchResult.users;
  int get totalUsersFound => _searchResult.total;
  bool get canLoadMore => _searchResult.hasMore && 
                         _searchState != SearchState.loadingMore && 
                         _currentQuery.isNotEmpty;

  //  GETTERS POSTS 
  bool get isSearchingPosts => _isSearchingPosts;
  List<PostWithDetails> get searchedPosts => _searchedPosts;
  String? get postsError => _postsError;
  bool get hasPostsResults => _searchedPosts.isNotEmpty;

  //  GETTERS UTILITAIRES 
  bool get isSearching => _searchState == SearchState.loading;
  bool get hasResults => _searchResult.users.isNotEmpty;

  //  INITIALISATION 

  /// Initialise le provider avec gestion d'erreurs
  Future<void> initialize() async {
    try {
      debugPrint('🚀 [SearchProvider] Initializing...');
      
      // Réinitialiser l'état
      _searchState = SearchState.initial;
      _searchError = null;
      _postsError = null;
      _searchResult = const SearchResult(posts: [], users: [], total: 0, hasMore: false);
      _searchedPosts = [];
      _isSearchingPosts = false;
      _currentQuery = '';
      _searchOffset = 0;
      
      notifyListeners();
      debugPrint('✅ [SearchProvider] Initialized successfully');
    } catch (e) {
      debugPrint('❌ [SearchProvider] Initialization error: $e');
      _searchError = 'Erreur d\'initialisation';
      _searchState = SearchState.error;
      notifyListeners();
    }
  }

  // RECHERCHE D'UTILISATEURS 

  /// Recherche des utilisateurs par username
  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      clearUserSearch();
      return;
    }

    try {
      final trimmedQuery = query.trim();
      
      // Si c'est une nouvelle recherche, reset
      if (_currentQuery != trimmedQuery) {
        _currentQuery = trimmedQuery;
        _searchOffset = 0;
        _searchState = SearchState.loading;
        _searchError = null;
        notifyListeners();
        
        // Track la recherche
        _trackUserSearch(trimmedQuery);
      } else if (_searchState == SearchState.loadingMore) {
        // Déjà en train de charger plus
        return;
      }

      debugPrint('🔍 [SearchProvider] Searching users: query="$_currentQuery"');

      final result = await _searchService.searchUsers(
        query: _currentQuery,
        limit: _pageSize,
        offset: _searchOffset,
      );

      if (result.isSuccess && result.data != null) {
        if (_searchOffset == 0) {
          // Nouveaux résultats
          _searchResult = result.data!;
        } else {
          // Ajouter aux résultats existants
          _searchResult = _searchResult.copyWith(
            users: [..._searchResult.users, ...result.data!.users],
            total: result.data!.total,
            hasMore: result.data!.hasMore,
          );
        }
        
        _searchOffset += _pageSize;
        _searchState = SearchState.loaded;
        _searchError = null;

        debugPrint('✅ [SearchProvider] Search completed: ${_searchResult.users.length} users found');
      } else {
        _searchState = SearchState.error;
        _searchError = result.error ?? 'Erreur de recherche';
        debugPrint('❌ [SearchProvider] Search failed: ${result.error}');
      }
    } catch (e, stackTrace) {
      _searchState = SearchState.error;
      _searchError = 'Erreur inattendue lors de la recherche';
      debugPrint('❌ [SearchProvider] Search error: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    notifyListeners();
  }

  /// Charge plus d'utilisateurs (pagination)
  Future<void> loadMoreUserSearchResults() async {
    if (!_searchResult.hasMore || 
        _searchState == SearchState.loadingMore || 
        _currentQuery.isEmpty) {
      return;
    }

    try {
      _searchState = SearchState.loadingMore;
      notifyListeners();

      debugPrint('📄 [SearchProvider] Loading more users: offset=$_searchOffset');

      final result = await _searchService.searchUsers(
        query: _currentQuery,
        limit: _pageSize,
        offset: _searchOffset,
      );

      if (result.isSuccess && result.data != null) {
        // Ajouter aux résultats existants
        _searchResult = _searchResult.copyWith(
          users: [..._searchResult.users, ...result.data!.users],
          total: result.data!.total,
          hasMore: result.data!.hasMore,
        );
        
        _searchOffset += _pageSize;
        _searchState = SearchState.loaded;
        _searchError = null;

        debugPrint('✅ [SearchProvider] More users loaded: ${_searchResult.users.length} total users');
      } else {
        _searchState = SearchState.error;
        _searchError = result.error ?? 'Erreur lors du chargement';
        debugPrint('❌ [SearchProvider] Load more failed: ${result.error}');
      }
    } catch (e, stackTrace) {
      _searchState = SearchState.error;
      _searchError = 'Erreur inattendue lors du chargement';
      debugPrint('❌ [SearchProvider] Load more error: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    notifyListeners();
  }

  /// Efface la recherche utilisateurs
  void clearUserSearch() {
    _searchState = SearchState.initial;
    _searchResult = const SearchResult(posts: [], users: [], total: 0, hasMore: false);
    _searchError = null;
    _currentQuery = '';
    _searchOffset = 0;
    
    debugPrint('🧹 [SearchProvider] User search cleared');
    notifyListeners();
  }

  /// Force le rafraîchissement de la recherche actuelle
  Future<void> refreshCurrentSearch() async {
    if (_currentQuery.isNotEmpty) {
      _searchOffset = 0;
      await searchUsers(_currentQuery);
    }
  }

  //  RECHERCHE DE POSTS 

  /// Recherche des posts par tags avec gestion d'erreurs robuste
  Future<void> searchPosts({List<String>? tags}) async {
    // Permettre la recherche même sans tags spécifiques
    if (tags == null) {
      tags = [];
    }

    // Vérification de l'état avant de commencer
    if (_isSearchingPosts) {
      debugPrint('⚠️ [SearchProvider] searchPosts already in progress');
      return;
    }

    _isSearchingPosts = true;
    _searchedPosts = [];
    _postsError = null;
    notifyListeners();

    try {
      debugPrint('🔍 [SearchProvider] Searching posts with tags: $tags');
      
      final result = await _searchService.searchPosts(
        tags: tags,
        query: '',
        limit: 20,
        offset: 0,
      );

      if (result.isSuccess && result.data != null) {
        final data = result.data!;
        
        // Gestion robuste des différents formats de données
        if (data is Map<String, dynamic>) {
          // Si c'est un objet avec une clé 'posts'
          if (data.containsKey('posts') && data['posts'] is List) {
            try {
              final postsList = data['posts'] as List;
              final posts = postsList
                  .map((e) => PostWithDetails.fromJson(e as Map<String, dynamic>))
                  .toList();
              _searchedPosts = posts;
              debugPrint('✅ [SearchProvider] Found ${_searchedPosts.length} posts from Map');
            } catch (e) {
              debugPrint('❌ [SearchProvider] Error parsing posts from Map: $e');
              _postsError = 'Erreur lors du parsing des posts';
            }
          } else {
            debugPrint('⚠️ [SearchProvider] Unexpected data format: ${data.keys}');
            _postsError = 'Format de données inattendu';
          }
        } else if (data is SearchResult) {
          // Si c'est déjà un SearchResult
_searchedPosts = (data['posts'] as List)
    .map((e) => PostWithDetails.fromJson(e as Map<String, dynamic>))
    .toList();
          debugPrint('✅ [SearchProvider] Found ${_searchedPosts.length} posts from SearchResult');
        } else if (data is List) {
          // Si c'est directement une liste
          try {
            final postsList = data as List;
            final posts = postsList
                .map((e) => PostWithDetails.fromJson(e as Map<String, dynamic>))
                .toList();
            _searchedPosts = posts;
            debugPrint('✅ [SearchProvider] Found ${_searchedPosts.length} posts from List');
          } catch (e) {
            debugPrint('❌ [SearchProvider] Error parsing posts from List: $e');
            _postsError = 'Erreur lors du parsing des posts';
          }
        } else {
          debugPrint('⚠️ [SearchProvider] Unknown data type: ${data.runtimeType}');
          _postsError = 'Type de données inconnu';
        }
        
        if (_searchedPosts.isEmpty && _postsError == null) {
          debugPrint('ℹ️ [SearchProvider] No posts found for tags: $tags');
        }
      } else {
        _postsError = result.error ?? 'Erreur de recherche de posts';
        debugPrint('❌ [SearchProvider] Search posts failed: ${result.error}');
      }
    } catch (e, stackTrace) {
      _postsError = 'Erreur inattendue lors de la recherche de posts';
      debugPrint('❌ [SearchProvider] Search posts error: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isSearchingPosts = false;
      notifyListeners();
    }
  }

  /// Efface la recherche de posts
  void clearPostSearch() {
    _searchedPosts = [];
    _isSearchingPosts = false;
    _postsError = null;
    debugPrint('🧹 [SearchProvider] Post search cleared');
    notifyListeners();
  }

  //  TRACKING DES INTERACTIONS 

  /// Track la visualisation d'un profil utilisateur
  Future<void> trackProfileView(UserSearchResult user) async {
    try {
      await _searchService.trackProfileView(user.id);
      debugPrint('📊 [SearchProvider] Profile view tracked: ${user.username}');
    } catch (e) {
      debugPrint('❌ [SearchProvider] Failed to track profile view: $e');
    }
  }

  /// Track une recherche utilisateur (privée)
  Future<void> _trackUserSearch(String query) async {
    try {
      await _searchService.trackSearch(query);
      debugPrint('📊 [SearchProvider] User search tracked: "$query"');
    } catch (e) {
      debugPrint('❌ [SearchProvider] Failed to track user search: $e');
    }
  }

  //  GESTION DES ERREURS 

  /// Message d'erreur formaté pour l'utilisateur (utilisateurs)
  String? get userFriendlyError {
    if (_searchError == null) return null;
    
    // Transformer les erreurs techniques en messages utilisateur
    if (_searchError!.contains('network') || _searchError!.contains('connection')) {
      return 'Problème de connexion. Vérifiez votre réseau.';
    } else if (_searchError!.contains('timeout')) {
      return 'La recherche prend trop de temps. Réessayez.';
    } else if (_searchError!.contains('server')) {
      return 'Problème serveur temporaire. Réessayez dans quelques instants.';
    } else if (_searchError!.contains('unauthorized') || _searchError!.contains('User ID required')) {
      return 'Problème d\'authentification. Veuillez vous reconnecter.';
    }
    
    return _searchError;
  }

  /// Message d'erreur formaté pour l'utilisateur (posts)
  String? get userFriendlyPostsError {
    if (_postsError == null) return null;
    
    // Transformer les erreurs techniques en messages utilisateur
    if (_postsError!.contains('network') || _postsError!.contains('connection')) {
      return 'Problème de connexion. Vérifiez votre réseau.';
    } else if (_postsError!.contains('timeout')) {
      return 'La recherche prend trop de temps. Réessayez.';
    } else if (_postsError!.contains('server')) {
      return 'Problème serveur temporaire. Réessayez dans quelques instants.';
    } else if (_postsError!.contains('unauthorized') || _postsError!.contains('User ID required')) {
      return 'Problème d\'authentification. Veuillez vous reconnecter.';
    }
    
    return _postsError;
  }

  //  MÉTHODES DE DEBUG 

  /// Affiche les statistiques de recherche
  void logSearchStats() {
    debugPrint('=== SEARCH STATS ===');
    debugPrint('State: $_searchState');
    debugPrint('Query: "$_currentQuery"');
    debugPrint('Users found: ${_searchResult.users.length}');
    debugPrint('Posts found: ${_searchedPosts.length}');
    debugPrint('Total users: ${_searchResult.total}');
    debugPrint('Has more users: ${_searchResult.hasMore}');
    debugPrint('Offset: $_searchOffset');
    debugPrint('Users Error: $_searchError');
    debugPrint('Posts Error: $_postsError');
    debugPrint('Is searching posts: $_isSearchingPosts');
    debugPrint('===');
  }

  //  RESET ET DISPOSE 

  /// Reset complet du provider
  void reset() {
    clearUserSearch();
    clearPostSearch();
    debugPrint('🔄 [SearchProvider] Complete reset');
  }

  /// Retry pour les erreurs
  Future<void> retryUserSearch() async {
    if (_currentQuery.isNotEmpty) {
      await searchUsers(_currentQuery);
    }
  }

  /// Retry pour les posts
  Future<void> retryPostSearch({List<String>? tags}) async {
    await searchPosts(tags: tags);
  }

  @override
  void dispose() {
    _searchService.clearCache();
    super.dispose();
    debugPrint('🗑️ [SearchProvider] Disposed');
  }
}