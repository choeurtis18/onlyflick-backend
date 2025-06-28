// lib/core/services/tags_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class TagsService {
  // Headers par défaut pour les requêtes
  static Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Récupère tous les tags disponibles en analysant les posts existants
  static Future<List<String>> getAvailableTags() async {
    try {
      // Récupérer tous les posts pour extraire les tags
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/posts/recommended?limit=100'),
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        Set<String> uniqueTags = {'Tous'}; // Commencer avec "Tous"
        
        if (data['posts'] != null) {
          List<dynamic> posts = data['posts'];
          
          // Extraire tous les tags de tous les posts
          for (var post in posts) {
            if (post['tags'] != null && post['tags'] is List) {
              List<dynamic> postTags = post['tags'];
              for (var tag in postTags) {
                if (tag != null && tag.toString().isNotEmpty) {
                  uniqueTags.add(tag.toString());
                }
              }
            }
          }
        }
        
        // Convertir en liste et trier (sauf "Tous" qui reste en premier)
        List<String> tags = uniqueTags.toList();
        tags.remove('Tous');
        tags.sort();
        tags.insert(0, 'Tous');
        
        return tags;
      }
      
      // En cas d'erreur, retourner des tags par défaut basés sur votre backend
      return [
        'Tous',
        'musculation',
        'yoga', 
        'fitness',
        'art',
        'cuisine',
        'mode',
        'musique'
      ];
      
    } catch (e) {
      print('Erreur lors de la récupération des tags: $e');
      // Fallback avec tags par défaut
      return [
        'Tous',
        'musculation',
        'yoga', 
        'fitness',
        'art',
        'cuisine',
        'mode',
        'musique'
      ];
    }
  }

  // Récupère les posts filtrés par tag
  static Future<Map<String, dynamic>> getPostsByTag(String tag, {
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      // Si le tag n'est pas "Tous", l'ajouter aux paramètres
      if (tag != 'Tous') {
        queryParams['tags'] = tag;
      }
      
      // SIMPLIFIÉ : Toujours utiliser l'endpoint recommended
      final uri = Uri.parse('${AppConfig.baseUrl}/posts/recommended')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        uri,
        headers: _defaultHeaders,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load posts: ${response.statusCode}');
      }
      
    } catch (e) {
      print('Erreur lors de la récupération des posts par tag: $e');
      rethrow;
    }
  }
}