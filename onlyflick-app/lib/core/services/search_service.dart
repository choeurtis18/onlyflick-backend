// lib/core/services/search_service.dart

import 'package:flutter/foundation.dart';
import '../models/search_models.dart';
import 'api_service.dart';

class SearchService {
  final ApiService _apiService = ApiService();
  
  // Cache simple pour éviter les requêtes redondantes
  final Map<String, SearchResult> _searchCache = {};

  /// Recherche des utilisateurs par username uniquement
  Future<ApiResponse<SearchResult>> searchUsers({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Vérifier le cache d'abord (seulement pour les nouvelles recherches sans offset)
      if (offset == 0) {
        final cacheKey = query.toLowerCase().trim();
        if (_searchCache.containsKey(cacheKey)) {
          debugPrint('📦 Cache hit for users search: "$query"');
          return ApiResponse.success(_searchCache[cacheKey]!);
        }
      }

      debugPrint('🔍 Searching users: query="$query", limit=$limit, offset=$offset');

      final response = await _apiService.get<Map<String, dynamic>>(
        '/search/users',
        queryParams: {
          'q': query,
          'limit': limit.toString(),
          'offset': offset.toString(),
        },
      );

      if (response.isSuccess && response.data != null) {
        try {
          // Parser la réponse du serveur
          final users = (response.data!['users'] as List? ?? [])
              .map((json) => UserSearchResult.fromJson(json))
              .toList();

          final total = response.data!['total'] as int? ?? 0;
          final hasMore = response.data!['has_more'] as bool? ?? false;

          final searchResult = SearchResult(
            users: users,
            posts: [], // Pas de posts dans la recherche utilisateurs
            total: total,
            hasMore: hasMore,
          );

          // Mettre en cache uniquement si c'est un nouveau résultat ET qu'il y a des résultats
          if (offset == 0 && users.isNotEmpty) {
            final cacheKey = query.toLowerCase().trim();
            _searchCache[cacheKey] = searchResult;
            debugPrint('📦 Cached search result for: "$query" (${users.length} users)');
          }

          debugPrint('✅ Users search completed: ${users.length} users found');
          return ApiResponse.success(searchResult);

        } catch (parseError) {
          debugPrint('❌ Failed to parse users search response: $parseError');
          debugPrint('Response data: ${response.data}');
          return ApiResponse.error('Erreur de format de réponse');
        }
      } else {
        debugPrint('❌ Users search failed: ${response.error}');
        return ApiResponse.error(response.error ?? 'Erreur de recherche');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Users search error: $e');
      debugPrint('Stack trace: $stackTrace');
      return ApiResponse.error('Erreur réseau lors de la recherche');
    }
  }

  /// Track une interaction utilisateur
  Future<void> trackInteraction({
    required UserInteractionType interactionType,
    required String contentType,
    required int contentId,
    String? contentMeta,
  }) async {
    try {
      debugPrint('📊 Tracking interaction: ${interactionType.name} on $contentType:$contentId');

      await _apiService.post<Map<String, dynamic>>(
        '/interactions/track',
        body: {
          'interaction_type': interactionType.name,
          'content_type': contentType,
          'content_id': contentId,
          if (contentMeta != null) 'content_meta': contentMeta,
        },
      );

      debugPrint('✅ Interaction tracked successfully');
    } catch (e) {
      debugPrint('❌ Failed to track interaction: $e');
      // Ne pas faire échouer l'opération principale si le tracking échoue
    }
  }

  /// Track la vue d'un profil
  Future<void> trackProfileView(int userId) async {
    await trackInteraction(
      interactionType: UserInteractionType.profileView,
      contentType: 'user',
      contentId: userId,
    );
  }

  /// Recherche des posts (avec tags et/ou query)
Future<ApiResponse<Map<String, dynamic>>> searchPosts({
  List<String>? tags,
  String? query,
  int limit = 20,
  int offset = 0,
  String sortBy = 'recent',
}) async {
  final queryParams = <String, String>{
    'limit': limit.toString(),
    'offset': offset.toString(),
    'sort_by': sortBy,
    'search_type': 'posts',
  };

  if (query != null && query.isNotEmpty) {
    queryParams['q'] = query;
  }

  if (tags != null && tags.isNotEmpty) {
    queryParams['tags'] = tags.join(',');
  }

  debugPrint('🔍 Recherche de posts: $queryParams');

  return _apiService.get<Map<String, dynamic>>(
    '/search/posts',
    queryParams: queryParams,
  );
}


  /// Track une recherche
  Future<void> trackSearch(String query) async {
    await trackInteraction(
      interactionType: UserInteractionType.search,
      contentType: 'search',
      contentId: 0,
      contentMeta: query,
    );
  }

  /// Vide le cache de recherche
  void clearCache() {
    _searchCache.clear();
    debugPrint('🧹 Search cache cleared');
  }

  void logCacheStats() {
    debugPrint('📊 Search cache stats: ${_searchCache.length} entries');
    for (final key in _searchCache.keys) {
      final result = _searchCache[key]!;
      debugPrint('  - $key: ${result.users.length} users');
    }
  }
}

/// Types d'interaction pour le tracking
enum UserInteractionType {
  view,
  like,
  comment,
  share,
  profileView,
  search,
  tagClick,
}