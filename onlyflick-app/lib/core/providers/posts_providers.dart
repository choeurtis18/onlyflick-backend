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
  loadingMore,
}

/// Provider pour la gestion des posts avec scroll infini
class PostsProvider extends ChangeNotifier {
  final PostsService _postsService = PostsService();
  final UserLikesCacheService _likesCache = UserLikesCacheService();

  // État du feed
  FeedState _state = FeedState.initial;
  List<Post> _posts = [];
  String? _error;
  int? _currentUserId;

  bool _hasMorePosts = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 10; // Taille des pages
  int _currentOffset = 0;

  // Cache des likes et commentaires
  final Map<int, int> _likesCountCache = {};
  final Map<int, List<Comment>> _commentsCache = {};
  final Map<int, bool> _userLikesCache = {};

  // Getters
  FeedState get state => _state;
  List<Post> get posts => _posts;
  String? get error => _error;
  bool get hasMorePosts => _hasMorePosts;
  bool get isLoadingMore => _isLoadingMore;
  
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

  ///  Charge la première page de posts
  Future<void> loadPosts() async {
    debugPrint('📱 Loading first page of posts...');
    
    _setState(FeedState.loading);
    _clearError();
    _resetPagination();

    try {
      final result = await _postsService.getAllPosts(
        limit: _pageSize,
        offset: 0,
      );

      if (result.isSuccess && result.data != null) {
        _posts = result.data!;
        _currentOffset = _posts.length;
        _hasMorePosts = _posts.length >= _pageSize;
        
        // Charger les likes pour cette première page
        await _loadLikesForCurrentPosts();
        
        _setState(FeedState.loaded);
        debugPrint('✅ ${_posts.length} posts loaded successfully');
      } else {
        _setError(result.error ?? 'Erreur lors du chargement des posts');
      }
    } catch (e) {
      debugPrint('❌ Load posts error: $e');
      _setError('Erreur réseau lors du chargement des posts');
    }
  }

  /// : Charge plus de posts pour le scroll infini
  Future<void> loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts || _state == FeedState.error) {
      return;
    }

    debugPrint('📱 Loading more posts... (offset: $_currentOffset)');
    
    _isLoadingMore = true;
    _setState(FeedState.loadingMore);

    try {
      final result = await _postsService.getAllPosts(
        limit: _pageSize,
        offset: _currentOffset,
      );

      if (result.isSuccess && result.data != null) {
        final newPosts = result.data!;
        
        if (newPosts.isNotEmpty) {
          _posts.addAll(newPosts);
          _currentOffset += newPosts.length;
          _hasMorePosts = newPosts.length >= _pageSize;
          
          // Charger les likes pour les nouveaux posts
          await _loadLikesForPosts(newPosts);
          
          debugPrint('✅ ${newPosts.length} more posts loaded (total: ${_posts.length})');
        } else {
          _hasMorePosts = false;
          debugPrint('🔚 No more posts to load');
        }
        
        _setState(FeedState.loaded);
      } else {
        debugPrint('❌ Failed to load more posts: ${result.error}');
        _setError(result.error ?? 'Erreur lors du chargement de plus de posts');
      }
    } catch (e) {
      debugPrint('❌ Load more posts error: $e');
      _setError('Erreur réseau lors du chargement de plus de posts');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Actualise le feed
  Future<void> refreshPosts() async {
    debugPrint('🔄 Refreshing posts...');
    
    _setState(FeedState.refreshing);
    _clearError();
    _resetPagination();

    try {
      final result = await _postsService.getAllPosts(
        limit: _pageSize,
        offset: 0,
      );

      if (result.isSuccess && result.data != null) {
        _posts = result.data!;
        _currentOffset = _posts.length;
        _hasMorePosts = _posts.length >= _pageSize;
        
        // Vider le cache des commentaires et recharger les likes
        _commentsCache.clear();
        await _loadLikesForCurrentPosts();
        
        _setState(FeedState.loaded);
        debugPrint('🔄 ${_posts.length} posts refreshed successfully');
      } else {
        _setError(result.error ?? 'Erreur lors de l\'actualisation des posts');
      }
    } catch (e) {
      debugPrint('❌ Refresh posts error: $e');
      _setError('Erreur réseau lors de l\'actualisation');
    }
  }

  /// Charge les likes pour tous les posts actuels
  Future<void> _loadLikesForCurrentPosts() async {
    await _loadLikesForPosts(_posts);
  }

  /// : Charge les likes pour une liste de posts spécifique
  Future<void> _loadLikesForPosts(List<Post> posts) async {
    final List<Future<void>> likesLoaders = [];
    
    for (final post in posts) {
      likesLoaders.add(_loadLikesForPost(post.id));
    }
    
    await Future.wait(likesLoaders);
    notifyListeners();
  }

  /// Charge les likes pour un post spécifique
  Future<void> _loadLikesForPost(int postId) async {
    try {
      final result = await _postsService.getPostLikeStatus(postId);
      
      if (result.isSuccess && result.likesCount != null && result.isLiked != null) {
        _likesCountCache[postId] = result.likesCount!;
        
        // Mettre à jour l'état du like utilisateur
        if (_currentUserId != null) {
          _userLikesCache[postId] = result.isLiked!;
          // Sauvegarder dans le cache persistant
          await _likesCache.saveLikeState(_currentUserId!, postId, result.isLiked!);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading likes for post $postId: $e');
    }
  }

  /// Remet à zéro la pagination
  void _resetPagination() {
    _currentOffset = 0;
    _hasMorePosts = true;
    _isLoadingMore = false;
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

      if (result.isSuccess && result.isLiked != null && result.likesCount != null) {
        final isLiked = result.isLiked!;
        final likesCount = result.likesCount!;
        
        // Mettre à jour le cache local
        _userLikesCache[postId] = isLiked;
        _likesCountCache[postId] = likesCount;
        
        // Sauvegarder dans le cache persistant
        await _likesCache.saveLikeState(_currentUserId!, postId, isLiked);
        
        notifyListeners();
        // debugPrint('❤️ Like toggled for post $postId: $isLiked (count: $likesCount)');
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
          _commentsCache[postId]!.insert(0, result.data!); 
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