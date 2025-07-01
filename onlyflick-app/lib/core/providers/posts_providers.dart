import 'package:flutter/material.dart';
import '../services/posts_service.dart';
import '../services/user_likes_cache_service.dart';
import '../models/post_models.dart';


/// États possibles pour le feed
enum FeedState {
  initial,
  loading,
  loaded,
  error,
  refreshing,
}

/// Provider pour la gestion des posts et du feed
class PostsProvider extends ChangeNotifier {
  final PostsService _postsService = PostsService();
  final UserLikesCacheService _likesCache = UserLikesCacheService();

  // État du feed
  FeedState _state = FeedState.initial;
  List<Post> _posts = [];
  String? _error;
  int? _currentUserId;

  // Cache des likes et commentaires
  final Map<int, int> _likesCountCache = {};
  final Map<int, List<Comment>> _commentsCache = {};
  final Map<int, bool> _userLikesCache = {};

  // Getters
  FeedState get state => _state;
  List<Post> get posts => _posts;
  String? get error => _error;
  
  bool get isLoading => _state == FeedState.loading;
  bool get isRefreshing => _state == FeedState.refreshing;
  bool get hasError => _state == FeedState.error;
  bool get hasData => _posts.isNotEmpty;

  /// Définit l'utilisateur actuel (appelé depuis AuthProvider)
  void setCurrentUser(int? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      _loadUserLikesFromCache();
    }
  }

  /// Charge les likes de l'utilisateur depuis le cache local
  Future<void> _loadUserLikesFromCache() async {
    if (_currentUserId == null) return;
    
    try {
      final userLikes = await _likesCache.getAllUserLikes(_currentUserId!);
      _userLikesCache.clear();
      _userLikesCache.addAll(userLikes);
      notifyListeners();
      // debugPrint('📖 Loaded ${userLikes.length} cached likes for user $_currentUserId');
    } catch (e) {
      debugPrint('❌ Error loading user likes from cache: $e');
    }
  }

  /// Initialise le feed
  Future<void> initializeFeed() async {
    if (_state == FeedState.initial) {
      await _loadUserLikesFromCache();
      await loadPosts();
    }
  }

  /// Charge tous les posts
  Future<void> loadPosts() async {
    // debugPrint('📱 Loading posts...');
    
    _setState(FeedState.loading);
    _clearError();

    try {
      final result = await _postsService.getAllPosts();

      if (result.isSuccess && result.data != null) {
        _posts = result.data!;
        _setState(FeedState.loaded);
        // debugPrint('📱 ${_posts.length} posts loaded successfully');
        
        // Précharger les likes pour chaque post
        _preloadLikes();
      } else {
        _setError(result.error ?? 'Erreur lors du chargement des posts');
      }
    } catch (e) {
      debugPrint('❌ Load posts error: $e');
      _setError('Erreur réseau lors du chargement des posts');
    }
  }

  /// Actualise le feed
  Future<void> refreshPosts() async {
    // debugPrint('🔄 Refreshing posts...');
    
    _setState(FeedState.refreshing);
    _clearError();

    try {
      final result = await _postsService.getAllPosts();

      if (result.isSuccess && result.data != null) {
        _posts = result.data!;
        _setState(FeedState.loaded);
        // debugPrint('🔄 ${_posts.length} posts refreshed successfully');
        
        // Ne pas vider le cache des likes utilisateur lors du refresh
        // Seulement vider le cache des commentaires et recharger les compteurs
        _commentsCache.clear();
        _preloadLikes();
      } else {
        _setError(result.error ?? 'Erreur lors de l\'actualisation des posts');
      }
    } catch (e) {
      debugPrint('❌ Refresh posts error: $e');
      _setError('Erreur réseau lors de l\'actualisation');
    }
  }

  /// Toggle like sur un post
  Future<void> toggleLike(int postId) async {
    if (_currentUserId == null) {
      debugPrint('❌ Cannot like: no user logged in');
      return;
    }

    // debugPrint('❤️ Toggling like for post: $postId');

    try {
      final result = await _postsService.toggleLike(postId);

      if (result.isSuccess && result.data != null) {
        final isLiked = result.data!;
        
        // Mettre à jour le cache local
        _userLikesCache[postId] = isLiked;
        
        // Sauvegarder dans le cache persistant
        await _likesCache.saveLikeState(_currentUserId!, postId, isLiked);
        
        // Mettre à jour le cache des likes count
        final currentCount = _likesCountCache[postId] ?? 0;
        _likesCountCache[postId] = isLiked ? currentCount + 1 : (currentCount > 0 ? currentCount - 1 : 0);
        
        notifyListeners();
        // debugPrint('❤️ Like toggled for post $postId: $isLiked');
      } else {
        debugPrint('❌ Failed to toggle like: ${result.error}');
      }
    } catch (e) {
      debugPrint('❌ Toggle like error: $e');
    }
  }

  /// Récupère le nombre de likes d'un post
  int getLikesCount(int postId) {
    return _likesCountCache[postId] ?? 0;
  }

  /// Vérifie si l'utilisateur a liké un post
  bool isLikedByUser(int postId) {
    return _userLikesCache[postId] ?? false;
  }

  /// Récupère les commentaires d'un post
  Future<List<Comment>> getComments(int postId) async {
    // Vérifier le cache d'abord
    if (_commentsCache.containsKey(postId)) {
      return _commentsCache[postId]!;
    }

    // debugPrint('💬 Loading comments for post: $postId');

    try {
      final result = await _postsService.getPostComments(postId);

      if (result.isSuccess && result.data != null) {
        _commentsCache[postId] = result.data!;
        notifyListeners();
        return result.data!;
      } else {
        debugPrint('❌ Failed to load comments: ${result.error}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Load comments error: $e');
      return [];
    }
  }

  /// Ajoute un commentaire à un post
  Future<bool> addComment(int postId, String content) async {
    // debugPrint('💬 Adding comment to post: $postId');

    try {
      final result = await _postsService.addComment(postId, content);

      if (result.isSuccess && result.data != null) {
        // Ajouter le commentaire au cache
        if (_commentsCache.containsKey(postId)) {
          _commentsCache[postId]!.add(result.data!);
        } else {
          _commentsCache[postId] = [result.data!];
        }
        
        notifyListeners();
        debugPrint('💬 Comment added successfully to post $postId');
        return true;
      } else {
        debugPrint('❌ Failed to add comment: ${result.error}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Add comment error: $e');
      return false;
    }
  }

  /// Récupère le nombre de commentaires d'un post
  int getCommentsCount(int postId) {
    return _commentsCache[postId]?.length ?? 0;
  }

  /// Précharge les likes pour tous les posts
  Future<void> _preloadLikes() async {
    for (final post in _posts) {
      _loadLikesForPost(post.id);
    }
  }

  /// Charge les likes pour un post spécifique
  Future<void> _loadLikesForPost(int postId) async {
    try {
      final result = await _postsService.getPostLikes(postId);
      
      if (result.isSuccess && result.data != null) {
        _likesCountCache[postId] = result.data!;
        
        // Charger l'état du like utilisateur depuis le cache si disponible
        if (_currentUserId != null && !_userLikesCache.containsKey(postId)) {
          final isLiked = await _likesCache.getLikeState(_currentUserId!, postId);
          _userLikesCache[postId] = isLiked;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading likes for post $postId: $e');
    }
  }

  /// Change l'état et notifie les listeners
  void _setState(FeedState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  /// Définit une erreur
  void _setError(String errorMessage) {
    _error = errorMessage;
    _setState(FeedState.error);
  }

  /// Efface l'erreur
  void _clearError() {
    _error = null;
  }

  /// Vide les caches (sauf les likes utilisateur)
  void _clearCache() {
    _likesCountCache.clear();
    _commentsCache.clear();
    // Ne pas effacer _userLikesCache ici car on veut le conserver
  }

  /// Nettoie les données de l'utilisateur (appelé lors de la déconnexion)
  Future<void> clearUserData() async {
    if (_currentUserId != null) {
      await _likesCache.clearUserLikes(_currentUserId!);
    }
    _userLikesCache.clear();
    _currentUserId = null;
    notifyListeners();
    // debugPrint('🗑️ User data cleared');
  }

  /// Retente le chargement en cas d'erreur
  Future<void> retry() async {
    await loadPosts();
  }

  @override
  void dispose() {
    _clearCache();
    super.dispose();
  }
}