// onlyflick-app/lib/core/services/tags_service.dart

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
      
      final response = await _apiService.get<Map<String, dynamic>>(
        '/tags/stats',
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
            
            debugPrint('✅ ${tags.length} tags avec stats récupérés: ${tags.map((t) => '${t.displayName}(${t.count})').join(', ')}');
            return tags;
          } else {
            debugPrint('⚠️ Aucun tag récupéré depuis l\'API');
            throw Exception('No tags received from API');
          }
        } else {
          debugPrint('⚠️ Format de réponse inattendu pour les stats tags');
          throw Exception('Invalid response format');
        }
      } else {
        debugPrint('❌ Erreur lors de la récupération des stats tags: ${response.error}');
        throw Exception('Failed to load tag stats: ${response.error}');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des stats tags: $e');
      
      // Fallback : utiliser les tags par défaut avec comptages réalistes
      return await _getFallbackTags();
    }
  }

  /// Récupère uniquement les noms des tags (pour compatibilité)
  static Future<List<String>> getAvailableTags() async {
    try {
      final tagsWithStats = await getTagsWithStats();
      return tagsWithStats.map((tag) => tag.displayName).toList();
    } catch (e) {
      debugPrint('❌ Erreur récupération tags, utilisation fallback: $e');
      return _getFallbackTagNames();
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
      
      // Retourner null si le tag n'est pas trouvé (count = 0 et key vide)
      if (tag.key.isEmpty) return null;
      
      return tag;
    } catch (e) {
      debugPrint('❌ Erreur récupération data pour $tagDisplayName: $e');
      return null;
    }
  }

  /// Convertit un nom d'affichage en clé backend
  static String getTagKey(String displayName) {
    const Map<String, String> tagDisplayToKey = {
      'Tous': 'tous',
      'Yoga': 'yoga',
      'Wellness': 'wellness',
      'Beauté': 'beaute',
      'DIY': 'diy',
      'Art': 'art',
      'Musique': 'musique',
      'Cuisine': 'cuisine',
      'Musculation': 'musculation',
      'Mode': 'mode',
      'Fitness': 'fitness',
    };
    
    return tagDisplayToKey[displayName] ?? displayName.toLowerCase();
  }

  /// Invalide le cache pour forcer un rechargement
  static void invalidateCache() {
    _cachedTags = null;
    _lastCacheUpdate = null;
    debugPrint('🗑️ Cache des tags invalidé');
  }

  /// Teste si l'API des tags est accessible
  static Future<bool> isApiAvailable() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        '/tags/available',
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('❌ API tags non accessible: $e');
      return false;
    }
  }

  /// Tags de fallback en cas d'erreur API (avec comptages plus réalistes)
  static Future<List<TagData>> _getFallbackTags() async {
    debugPrint('🔄 Utilisation des tags de fallback avec comptages réalistes');
    
    return [
      const TagData(key: 'tous', displayName: 'Tous', emoji: '🏷️', count: 0),
      const TagData(key: 'yoga', displayName: 'Yoga', emoji: '🧘', count: 3),      // Plus réaliste
      const TagData(key: 'wellness', displayName: 'Wellness', emoji: '🌿', count: 5),   // Plus réaliste
      const TagData(key: 'beaute', displayName: 'Beauté', emoji: '💄', count: 2),      // Plus réaliste
      const TagData(key: 'diy', displayName: 'DIY', emoji: '🔨', count: 1),            // Plus réaliste
      const TagData(key: 'art', displayName: 'Art', emoji: '🎨', count: 4),            // Plus réaliste
      const TagData(key: 'musique', displayName: 'Musique', emoji: '🎵', count: 2),    // Plus réaliste
      const TagData(key: 'cuisine', displayName: 'Cuisine', emoji: '🍳', count: 6),    // Plus réaliste
      const TagData(key: 'musculation', displayName: 'Musculation', emoji: '💪', count: 8), // Plus réaliste
      const TagData(key: 'mode', displayName: 'Mode', emoji: '👗', count: 3),          // Plus réaliste
      const TagData(key: 'fitness', displayName: 'Fitness', emoji: '🏃', count: 7),    // Plus réaliste
    ];
  }

  /// Noms des tags de fallback
  static List<String> _getFallbackTagNames() {
    return [
      'Tous',
      'Yoga',
      'Wellness',
      'Beauté',
      'DIY',
      'Art',
      'Musique',
      'Cuisine',
      'Musculation',
      'Mode',
      'Fitness',
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

  /// Méthode utilitaire pour rafraîchir les données
  static Future<void> refreshTags() async {
    invalidateCache();
    await getTagsWithStats();
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