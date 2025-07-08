// lib/core/services/tags_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Modèle pour un tag avec ses métadonnées
class TagData {
  final String key;
  final String displayName;
  final String emoji;
  final int count;

  const TagData({
    required this.key,
    required this.displayName,
    required this.emoji,
    required this.count,
  });

  factory TagData.fromJson(Map<String, dynamic> json) {
    return TagData(
      key: json['key'] ?? '',
      displayName: json['displayName'] ?? '',
      emoji: json['emoji'] ?? '🏷️',
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'displayName': displayName,
        'emoji': emoji,
        'count': count,
      };

  @override
  String toString() => 'TagData(key: $key, displayName: $displayName, count: $count)';
}

/// Service pour la gestion des tags et de leurs statistiques
class TagsService {
  static final ApiService _apiService = ApiService();
  
  // Cache pour éviter les appels répétés
  static List<TagData>? _cachedTags;
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Récupère tous les tags disponibles avec leurs statistiques depuis l'API
  static Future<List<TagData>> getTagsWithStats() async {
    try {
      // Vérifier le cache
      if (_cachedTags != null && 
          _lastCacheUpdate != null && 
          DateTime.now().difference(_lastCacheUpdate!) < _cacheTimeout) {
        debugPrint('🏷️ Utilisation des tags en cache (${_cachedTags!.length} tags)');
        return _cachedTags!;
      }

      debugPrint('🏷️ Récupération des tags avec statistiques depuis l\'API...');
      
      // ✅ Essayer d'abord l'endpoint tags/stats
      try {
        final response = await _apiService.get<Map<String, dynamic>>(
          '/search/tags/stats',
        );

        if (response.isSuccess && response.data != null) {
          final data = response.data!;
          
          if (data['tags'] != null && data['tags'] is List) {
            List<TagData> tags = [];
            
            for (var tagJson in data['tags']) {
              if (tagJson is Map<String, dynamic>) {
                try {
                  tags.add(TagData.fromJson(tagJson));
                } catch (e) {
                  debugPrint('⚠️ Erreur parsing tag: $e');
                }
              }
            }
            
            // Mettre en cache seulement si on a récupéré des données valides
            if (tags.isNotEmpty) {
              _cachedTags = tags;
              _lastCacheUpdate = DateTime.now();
              
              debugPrint('✅ ${tags.length} tags avec stats récupérés depuis API: ${tags.map((t) => '${t.displayName}(${t.count})').join(', ')}');
              return tags;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Endpoint /search/tags/stats non disponible: $e');
      }

      // ✅ Fallback: analyser les posts existants pour extraire les tags
      debugPrint('🔄 Fallback: analyse des posts pour extraire les tags...');
      return await _getTagsFromPosts();
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des stats tags: $e');
      
      // Fallback final : utiliser les tags par défaut
      return await _getFallbackTags();
    }
  }

  /// ✅ Méthode pour extraire les tags depuis les posts existants
  static Future<List<TagData>> _getTagsFromPosts() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/posts/recommended',
        queryParams: {'limit': '100'}, // Récupérer plus de posts pour avoir plus de tags
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        
        // Compter les occurrences de chaque tag
        Map<String, int> tagCounts = {};
        
        if (data['posts'] != null && data['posts'] is List) {
          List<dynamic> posts = data['posts'];
          
          for (var post in posts) {
            if (post['tags'] != null && post['tags'] is List) {
              List<dynamic> postTags = post['tags'];
              for (var tag in postTags) {
                if (tag != null && tag.toString().isNotEmpty) {
                  String backendTag = tag.toString().toLowerCase();
                  tagCounts[backendTag] = (tagCounts[backendTag] ?? 0) + 1;
                }
              }
            }
          }
        }
        
        // Convertir en TagData avec les vrais comptages
        List<TagData> tags = [
          TagData(key: 'tous', displayName: 'Tous', emoji: '🏷️', count: data['total'] ?? 0),
        ];
        
        // Ajouter les tags trouvés avec leurs comptages
        for (String backendTag in tagCounts.keys) {
          String displayName = getTagDisplayName(backendTag);
          String emoji = _getTagEmoji(backendTag);
          int count = tagCounts[backendTag] ?? 0;
          
          if (displayName.isNotEmpty && displayName != 'Tous') {
            tags.add(TagData(
              key: backendTag,
              displayName: displayName,
              emoji: emoji,
              count: count,
            ));
          }
        }
        
        // Ajouter les tags manquants avec count 0
        List<String> allValidTags = _getValidBackendTags();
        for (String validTag in allValidTags) {
          if (!tagCounts.containsKey(validTag)) {
            tags.add(TagData(
              key: validTag,
              displayName: getTagDisplayName(validTag),
              emoji: _getTagEmoji(validTag),
              count: 0,
            ));
          }
        }
        
        // Trier par count décroissant (sauf "Tous" qui reste en premier)
        tags.sort((a, b) {
          if (a.key == 'tous') return -1;
          if (b.key == 'tous') return 1;
          return b.count.compareTo(a.count);
        });
        
        // Mettre en cache
        if (tags.isNotEmpty) {
          _cachedTags = tags;
          _lastCacheUpdate = DateTime.now();
          
          debugPrint('✅ ${tags.length} tags extraits depuis posts: ${tags.map((t) => '${t.displayName}(${t.count})').join(', ')}');
          return tags;
        }
      }
      
      // Si échec, utiliser les tags par défaut
      return await _getFallbackTags();
      
    } catch (e) {
      debugPrint('❌ Erreur extraction tags depuis posts: $e');
      return await _getFallbackTags();
    }
  }

  /// Récupère uniquement les noms des tags (pour compatibilité)
  static Future<List<String>> getAvailableTags() async {
    try {
      final tagsWithStats = await getTagsWithStats();
      final tags = tagsWithStats.map((tag) => tag.displayName).toList();
      
      if (tags.isNotEmpty) {
        debugPrint('✅ Tags disponibles récupérés: $tags');
        return tags;
      }
      
      // Fallback
      return _getFallbackTagNames();
    } catch (e) {
      debugPrint('❌ Erreur récupération tags, utilisation fallback: $e');
      return _getFallbackTagNames();
    }
  }

  /// ✅ Méthode pour récupérer les posts filtrés par tag
  static Future<Map<String, dynamic>> getPostsByTag(String tag, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      // Convertir le tag d'affichage vers le backend
      if (tag != 'Tous') {
        String backendTag = getTagKey(tag);
        if (backendTag.isNotEmpty && backendTag != 'tous') {
          queryParams['tags'] = backendTag;
          debugPrint('🔍 Recherche posts avec tag backend: $backendTag (depuis: $tag)');
        }
      }
      
      final response = await _apiService.get<Map<String, dynamic>>(
        '/posts/recommended',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        final result = response.data!;
        debugPrint('✅ Posts récupérés: ${result['posts']?.length ?? 0} posts pour tag: $tag');
        return result;
      } else {
        debugPrint('❌ Erreur API getPostsByTag: ${response.error}');
        throw Exception('Failed to load posts: ${response.error}');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des posts par tag: $e');
      rethrow;
    }
  }

  /// Récupère les statistiques d'un tag spécifique
  static Future<int> getTagCount(String tagDisplayName) async {
    try {
      final tagsWithStats = await getTagsWithStats();
      final tag = tagsWithStats.firstWhere(
        (t) => t.displayName.toLowerCase() == tagDisplayName.toLowerCase(),
        orElse: () => const TagData(key: '', displayName: '', emoji: '', count: 0),
      );
      return tag.count;
    } catch (e) {
      debugPrint('❌ Erreur récupération count pour $tagDisplayName: $e');
      return 0;
    }
  }

  /// Récupère les métadonnées d'un tag (nom, emoji, etc.)
  static Future<TagData?> getTagData(String tagDisplayName) async {
    try {
      final tagsWithStats = await getTagsWithStats();
      final tag = tagsWithStats.firstWhere(
        (t) => t.displayName.toLowerCase() == tagDisplayName.toLowerCase(),
        orElse: () => const TagData(key: '', displayName: '', emoji: '', count: 0),
      );
      
      if (tag.key.isEmpty) return null;
      return tag;
    } catch (e) {
      debugPrint('❌ Erreur récupération data pour $tagDisplayName: $e');
      return null;
    }
  }

  /// ✅ Convertit un nom d'affichage en clé backend
  static String getTagKey(String displayName) {
    const Map<String, String> tagDisplayToKey = {
      'Tous': 'tous',
      'Wellness': 'wellness',
      'Beauté': 'beaute',
      'Art': 'art',
      'Musique': 'musique',
      'Cuisine': 'cuisine',
      'Football': 'football',
      'Basket': 'basket',
      'Basketball': 'basket', // Alias
      'Mode': 'mode',
      'Cinéma': 'cinema',
      'Actualités': 'actualites',
      'Mangas': 'mangas',
      'Memes': 'memes',
      'Tech': 'tech',
    };
    
    return tagDisplayToKey[displayName] ?? displayName.toLowerCase();
  }

  /// ✅ Convertit une clé backend en nom d'affichage
  static String getTagDisplayName(String key) {
    const Map<String, String> tagKeyToDisplay = {
      'tous': 'Tous',
      'wellness': 'Wellness',
      'beaute': 'Beauté',
      'art': 'Art',
      'musique': 'Musique',
      'cuisine': 'Cuisine',
      'football': 'Football',
      'basket': 'Basketball',
      'mode': 'Mode',
      'cinema': 'Cinéma',
      'actualites': 'Actualités',
      'mangas': 'Mangas',
      'memes': 'Memes',
      'tech': 'Tech',
    };
    
    return tagKeyToDisplay[key.toLowerCase()] ?? key;
  }

  /// ✅ Retourne l'emoji d'un tag backend
  static String _getTagEmoji(String backendTag) {
    const Map<String, String> tagEmojis = {
      'wellness': '🧘',
      'beaute': '💄',
      'art': '🎨',
      'musique': '🎵',
      'cuisine': '🍳',
      'football': '⚽',
      'basket': '🏀',
      'mode': '👗',
      'cinema': '🎬',
      'actualites': '📰',
      'mangas': '📚',
      'memes': '😂',
      'tech': '💻',
    };
    
    return tagEmojis[backendTag.toLowerCase()] ?? '🏷️';
  }

  /// ✅ Retourne la liste des tags backend valides
  static List<String> _getValidBackendTags() {
    return [
      'wellness',
      'beaute',
      'art',
      'musique',
      'cuisine',
      'football',
      'basket',
      'mode',
      'cinema',
      'actualites',
      'mangas',
      'memes',
      'tech',
    ];
  }

  /// Invalide le cache pour forcer un rechargement
  static void invalidateCache() {
    _cachedTags = null;
    _lastCacheUpdate = null;
    debugPrint('🗑️ Cache des tags invalidé');
  }

  /// ✅ Force le rafraîchissement des tags
  static Future<List<String>> refreshTags() async {
    debugPrint('🔄 Rafraîchissement forcé des tags...');
    invalidateCache();
    return await getAvailableTags();
  }

  /// Teste si l'API des tags est accessible
  static Future<bool> isApiAvailable() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/search/tags/stats',
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('❌ API tags non accessible: $e');
      return false;
    }
  }

  /// ✅ Tags de fallback en cas d'erreur API (comptages réalistes)
  static Future<List<TagData>> _getFallbackTags() async {
    debugPrint('🔄 Utilisation des tags de fallback avec comptages estimés');
    
    return [
      const TagData(key: 'tous', displayName: 'Tous', emoji: '🏷️', count: 0),
      const TagData(key: 'art', displayName: 'Art', emoji: '🎨', count: 10),
      const TagData(key: 'musique', displayName: 'Musique', emoji: '🎵', count: 10),
      const TagData(key: 'tech', displayName: 'Tech', emoji: '💻', count: 7),
      const TagData(key: 'cuisine', displayName: 'Cuisine', emoji: '🍳', count: 8),
      const TagData(key: 'wellness', displayName: 'Wellness', emoji: '🧘', count: 7),
      const TagData(key: 'beaute', displayName: 'Beauté', emoji: '💄', count: 7),
      const TagData(key: 'mode', displayName: 'Mode', emoji: '👗', count: 5),
      const TagData(key: 'football', displayName: 'Football', emoji: '⚽', count: 5),
      const TagData(key: 'basket', displayName: 'Basketball', emoji: '🏀', count: 5),
      const TagData(key: 'cinema', displayName: 'Cinéma', emoji: '🎬', count: 5),
      const TagData(key: 'actualites', displayName: 'Actualités', emoji: '📰', count: 5),
      const TagData(key: 'mangas', displayName: 'Mangas', emoji: '📚', count: 5),
      const TagData(key: 'memes', displayName: 'Memes', emoji: '😂', count: 5),
    ];
  }

  /// ✅ Noms des tags de fallback
  static List<String> _getFallbackTagNames() {
    return [
      'Tous',
      'Art',
      'Musique', 
      'Tech',
      'Cuisine',
      'Wellness',
      'Beauté',
      'Mode',
      'Football',
      'Basketball',
      'Cinéma',
      'Actualités',
      'Mangas',
      'Memes',
    ];
  }

  /// Récupère les tags les plus populaires (les plus utilisés)
  static Future<List<TagData>> getPopularTags({int limit = 5}) async {
    try {
      final tagsWithStats = await getTagsWithStats();
      
      // Exclure "Tous" et trier par count décroissant
      final popularTags = tagsWithStats
          .where((tag) => tag.key != 'tous' && tag.count > 0)
          .toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      
      return popularTags.take(limit).toList();
    } catch (e) {
      debugPrint('❌ Erreur récupération tags populaires: $e');
      return [];
    }
  }

  /// Recherche des tags par nom
  static Future<List<TagData>> searchTags(String query) async {
    if (query.isEmpty) return [];
    
    try {
      final allTags = await getTagsWithStats();
      
      return allTags
          .where((tag) => 
              tag.displayName.toLowerCase().contains(query.toLowerCase()) ||
              tag.key.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur recherche tags: $e');
      return [];
    }
  }

  /// Retourne les statistiques générales des tags
  static Future<Map<String, dynamic>> getTagsOverview() async {
    try {
      final tags = await getTagsWithStats();
      
      final totalTags = tags.length - 1; // Exclure "Tous"
      final totalPosts = tags.isNotEmpty ? tags.first.count : 0; // "Tous" contient le total
      final tagsWithPosts = tags.where((tag) => tag.key != 'tous' && tag.count > 0).length;
      
      return {
        'total_tags': totalTags,
        'total_posts': totalPosts,
        'tags_with_posts': tagsWithPosts,
        'empty_tags': totalTags - tagsWithPosts,
        'last_update': _lastCacheUpdate?.toIso8601String() ?? '',
      };
    } catch (e) {
      debugPrint('❌ Erreur récupération overview tags: $e');
      return {};
    }
  }
}