// lib/core/services/tags_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class TagsService {
  static final ApiService _apiService = ApiService();

  // Map pour correspondance nom d'affichage -> clé backend
  static final Map<String, String> _tagDisplayToKey = {
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

  // Convertit un nom d'affichage en clé backend
  static String getTagKey(String displayName) {
    return _tagDisplayToKey[displayName] ?? displayName.toLowerCase();
  }

  // Récupère tous les tags disponibles depuis l'endpoint dédié
  static Future<List<String>> getAvailableTags() async {
    try {
      debugPrint('🏷️ Récupération des tags disponibles depuis l\'API...');
      
      // Utiliser l'ApiService pour récupérer les tags depuis l'endpoint dédié
      final response = await _apiService.get<Map<String, dynamic>>(
        '/tags/available',
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        
        if (data['tags'] != null && data['tags'] is List) {
          List<String> tags = [];
          
          for (var tagData in data['tags']) {
            if (tagData is Map<String, dynamic> && tagData['displayName'] != null) {
              tags.add(tagData['displayName'].toString());
            }
          }
          
          debugPrint('✅ ${tags.length} tags récupérés depuis l\'API: $tags');
          return tags;
        } else {
          debugPrint('⚠️ Format de réponse inattendu pour les tags');
          throw Exception('Invalid response format');
        }
      } else {
        debugPrint('❌ Erreur lors de la récupération des tags: ${response.error}');
        throw Exception('Failed to load tags: ${response.error}');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des tags: $e');
      // Fallback avec tags correspondant à ceux du backend
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
  }

  // Récupère les tags avec leurs métadonnées complètes (clé, nom, emoji)
  static Future<List<Map<String, dynamic>>> getAvailableTagsWithMetadata() async {
    try {
      debugPrint('🏷️ Récupération des tags avec métadonnées...');
      
      final response = await _apiService.get<Map<String, dynamic>>(
        '/tags/available',
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        
        if (data['tags'] != null && data['tags'] is List) {
          List<Map<String, dynamic>> tags = [];
          
          for (var tagData in data['tags']) {
            if (tagData is Map<String, dynamic>) {
              tags.add({
                'key': tagData['key'] ?? '',
                'displayName': tagData['displayName'] ?? '',
                'emoji': tagData['emoji'] ?? '🏷️',
              });
            }
          }
          
          debugPrint('✅ ${tags.length} tags avec métadonnées récupérés');
          return tags;
        }
      }
      
      // Fallback avec tags par défaut
      return [
        {'key': 'tous', 'displayName': 'Tous', 'emoji': '🏷️'},
        {'key': 'yoga', 'displayName': 'Yoga', 'emoji': '🧘'},
        {'key': 'wellness', 'displayName': 'Wellness', 'emoji': '🌿'},
        {'key': 'beaute', 'displayName': 'Beauté', 'emoji': '💄'},
        {'key': 'diy', 'displayName': 'DIY', 'emoji': '🛠️'},
        {'key': 'art', 'displayName': 'Art', 'emoji': '🎨'},
        {'key': 'musique', 'displayName': 'Musique', 'emoji': '🎵'},
        {'key': 'cuisine', 'displayName': 'Cuisine', 'emoji': '🍽️'},
        {'key': 'musculation', 'displayName': 'Musculation', 'emoji': '🏋️'},
        {'key': 'mode', 'displayName': 'Mode', 'emoji': '👗'},
        {'key': 'fitness', 'displayName': 'Fitness', 'emoji': '💪'},
      ];
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des tags avec métadonnées: $e');
      rethrow;
    }
  }

  // Récupère les posts filtrés par tag
  static Future<Map<String, dynamic>> getPostsByTag(String tagDisplayName, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      // Convertir le nom d'affichage en clé backend
      String tagKey = getTagKey(tagDisplayName);
      
      // Si le tag n'est pas "tous", l'ajouter aux paramètres
      if (tagKey != 'tous') {
        queryParams['tags'] = tagKey;
      }
      
      debugPrint('🔍 Requête posts recommandés avec tag: $tagDisplayName -> $tagKey, limit: $limit, offset: $offset');
      
      // Utiliser l'ApiService pour l'authentification automatique
      final response = await _apiService.get<Map<String, dynamic>>(
        '/posts/recommended',
        queryParams: queryParams,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        debugPrint('✅ Posts récupérés avec succès: ${data['posts']?.length ?? 0} posts');
        return data;
      } else {
        debugPrint('❌ Erreur lors de la récupération des posts: ${response.error}');
        throw Exception('Failed to load posts: ${response.error}');
      }
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la récupération des posts par tag: $e');
      rethrow;
    }
  }
}