import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer le cache local des likes utilisateur
class UserLikesCacheService {
  static const String _keyPrefix = 'user_likes_';
  
  /// Sauvegarde l'état d'un like pour un utilisateur
  Future<void> saveLikeState(int userId, int postId, bool isLiked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyPrefix}${userId}_$postId';
      await prefs.setBool(key, isLiked);
      debugPrint('💾 Like state saved: user $userId, post $postId, liked: $isLiked');
    } catch (e) {
      debugPrint('❌ Error saving like state: $e');
    }
  }

  /// Récupère l'état d'un like pour un utilisateur
  Future<bool> getLikeState(int userId, int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyPrefix}${userId}_$postId';
      final isLiked = prefs.getBool(key) ?? false;
      debugPrint('📖 Like state loaded: user $userId, post $postId, liked: $isLiked');
      return isLiked;
    } catch (e) {
      debugPrint('❌ Error loading like state: $e');
      return false;
    }
  }

  /// Récupère tous les likes d'un utilisateur
  Future<Map<int, bool>> getAllUserLikes(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = '${_keyPrefix}$userId';
      final Map<int, bool> likes = {};
      
      for (final key in prefs.getKeys()) {
        if (key.startsWith(userPrefix)) {
          // Extraire l'ID du post de la clé
          final postIdStr = key.substring(userPrefix.length + 1); // +1 pour le _
          final postId = int.tryParse(postIdStr);
          if (postId != null) {
            likes[postId] = prefs.getBool(key) ?? false;
          }
        }
      }
      
      debugPrint('📖 Loaded ${likes.length} likes for user $userId');
      return likes;
    } catch (e) {
      debugPrint('❌ Error loading user likes: $e');
      return {};
    }
  }

  /// Supprime un like spécifique
  Future<void> removeLikeState(int userId, int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyPrefix}${userId}_$postId';
      await prefs.remove(key);
      debugPrint('🗑️ Like state removed: user $userId, post $postId');
    } catch (e) {
      debugPrint('❌ Error removing like state: $e');
    }
  }

  /// Supprime tous les likes d'un utilisateur (utile lors de la déconnexion)
  Future<void> clearUserLikes(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userPrefix = '${_keyPrefix}$userId';
      final keysToRemove = prefs.getKeys()
          .where((key) => key.startsWith(userPrefix))
          .toList();
      
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
      
      debugPrint('🗑️ Cleared ${keysToRemove.length} likes for user $userId');
    } catch (e) {
      debugPrint('❌ Error clearing user likes: $e');
    }
  }
}