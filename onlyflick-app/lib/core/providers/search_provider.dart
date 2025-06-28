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

/// Provider simplifié pour la recherche d'utilisateurs uniquement
class SearchProvider with ChangeNotifier {
  final SearchService _searchService = SearchService();

  // ===== ÉTAT DE LA RECHERCHE UTILISATEURS =====
  SearchState _searchState = SearchState.initial;
  SearchResult _searchResult = const SearchResult(posts: [], users: [], total: 0, hasMore: false);
  String? _searchError;
  String _currentQuery = '';
  
  // ===== PAGINATION =====
  static const int _pageSize = 20;
  int _searchOffset = 0;

  // ===== GETTERS =====
  SearchState get searchState => _searchState;
  SearchResult get searchResult => _searchResult;
  String? get searchError => _searchError;
  String get currentQuery => _currentQuery;
  bool get isLoading => _searchState == SearchState.loading;
  bool get isLoadingMoreSearch => _searchState == SearchState.loadingMore;
  bool get hasSearchResults => _searchResult.users.isNotEmpty;
  bool _isSearchingPosts = false;
  List<PostWithDetails> _searchedPosts = [];
  bool get isSearchingPosts => _isSearchingPosts;
  List<PostWithDetails> get searchedPosts => _searchedPosts;


  // ===== RECHERCHE D'UTILISATEURS =====

  /// Recherche des utilisateurs par username uniquement
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

      debugPrint('🔍 Searching users: query="$_currentQuery"');

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

        debugPrint('✅ Search completed: ${_searchResult.users.length} users found');
      } else {
        _searchState = SearchState.error;
        _searchError = result.error ?? 'Erreur de recherche';
        debugPrint('❌ Search failed: ${result.error}');
      }
    } catch (e, stackTrace) {
      _searchState = SearchState.error;
      _searchError = 'Erreur inattendue lors de la recherche';
      debugPrint('❌ Search error: $e');
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

      debugPrint('📄 Loading more users: offset=$_searchOffset');

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

        debugPrint('✅ More users loaded: ${_searchResult.users.length} total users');
      } else {
        _searchState = SearchState.error;
        _searchError = result.error ?? 'Erreur lors du chargement';
        debugPrint('❌ Load more failed: ${result.error}');
      }
    } catch (e, stackTrace) {
      _searchState = SearchState.error;
      _searchError = 'Erreur inattendue lors du chargement';
      debugPrint('❌ Load more error: $e');
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
    
    debugPrint('🧹 User search cleared');
    notifyListeners();
  }

  /// Force le rafraîchissement de la recherche actuelle
  Future<void> refreshCurrentSearch() async {
    if (_currentQuery.isNotEmpty) {
      _searchOffset = 0;
      await searchUsers(_currentQuery);
    }
  }

  Future<void> searchPosts({List<String>? tags}) async {
  _isSearchingPosts = true;
  _searchedPosts = [];
  notifyListeners();

  try {
    final result = await _searchService.searchPosts(
      tags: tags ?? [],
      query: '',
      limit: 20,
      offset: 0,
    );

    if (result.isSuccess && result.data != null) {
      final data = result.data!;
      final posts = (data['posts'] as List)
          .map((e) => PostWithDetails.fromJson(e))
          .toList();
      _searchedPosts = posts;
    } else {
      debugPrint('❌ Échec recherche posts: ${result.error}');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Exception recherche posts: $e');
    debugPrint('Stack: $stackTrace');
  } finally {
    _isSearchingPosts = false;
    notifyListeners();
  }
}

void clearPostSearch() {
  _searchedPosts = [];
  _isSearchingPosts = false;
  notifyListeners();
}


  // ===== TRACKING DES INTERACTIONS =====

  /// Track la visualisation d'un profil utilisateur
  Future<void> trackProfileView(UserSearchResult user) async {
    try {
      await _searchService.trackProfileView(user.id);
      
      debugPrint('📊 Profile view tracked: ${user.username}');
    } catch (e) {
      debugPrint('❌ Failed to track profile view: $e');
    }
  }

  /// Track une recherche utilisateur (privée)
  Future<void> _trackUserSearch(String query) async {
    try {
      await _searchService.trackSearch(query);
      
      debugPrint('📊 User search tracked: "$query"');
    } catch (e) {
      debugPrint('❌ Failed to track user search: $e');
    }
  }

  // ===== MÉTHODES UTILITAIRES =====

  /// Vérifie si on peut charger plus de résultats
  bool get canLoadMore => _searchResult.hasMore && 
                         _searchState != SearchState.loadingMore && 
                         _currentQuery.isNotEmpty;

  /// Nombre total d'utilisateurs trouvés
  int get totalUsersFound => _searchResult.total;

  /// Liste des utilisateurs trouvés
  List<UserSearchResult> get searchedUsers => _searchResult.users;

  /// Indique si une recherche est en cours
  bool get isSearching => _searchState == SearchState.loading;

  /// Indique si des résultats sont disponibles
  bool get hasResults => _searchResult.users.isNotEmpty;

  /// Message d'erreur formaté pour l'utilisateur
  String? get userFriendlyError {
    if (_searchError == null) return null;
    
    // Transformer les erreurs techniques en messages utilisateur
    if (_searchError!.contains('network') || _searchError!.contains('connection')) {
      return 'Problème de connexion. Vérifiez votre réseau.';
    } else if (_searchError!.contains('timeout')) {
      return 'La recherche prend trop de temps. Réessayez.';
    } else if (_searchError!.contains('server')) {
      return 'Problème serveur temporaire. Réessayez dans quelques instants.';
    }
    
    return _searchError;
  }

  // ===== MÉTHODES DE DEBUG =====

  /// Affiche les statistiques de recherche
  void logSearchStats() {
    debugPrint('=== SEARCH STATS ===');
    debugPrint('State: $_searchState');
    debugPrint('Query: "$_currentQuery"');
    debugPrint('Users found: ${_searchResult.users.length}');
    debugPrint('Total: ${_searchResult.total}');
    debugPrint('Has more: ${_searchResult.hasMore}');
    debugPrint('Offset: $_searchOffset');
    debugPrint('Error: $_searchError');
    debugPrint('==================');
  }

  // ===== RESET ET DISPOSE =====

  /// Reset complet du provider
  void reset() {
    clearUserSearch();
    debugPrint('🔄 SearchProvider reset');
  }

  /// Initialise le provider (optionnel pour cette version simplifiée)
  Future<void> initialize() async {
    debugPrint('🚀 SearchProvider initialized (simplified version)');
  }

  @override
  void dispose() {
    _searchService.clearCache();
    super.dispose();
  }
}