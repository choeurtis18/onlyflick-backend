// lib/features/posts/widgets/recommended_posts_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/models/post_models.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/providers/posts_providers.dart';
import '../pages/post_detail_page.dart';

class RecommendedPostsSection extends StatefulWidget {
  final String selectedTag;

  const RecommendedPostsSection({
    super.key,
    this.selectedTag = 'Tous',
  });

  @override
  State<RecommendedPostsSection> createState() => _RecommendedPostsSectionState();
}

class _RecommendedPostsSectionState extends State<RecommendedPostsSection> {
  final ApiService _apiService = ApiService();
  
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Pagination
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMorePosts = false;
  bool _isLoadingMore = false;
  int _totalPosts = 0;

  @override
  void initState() {
    super.initState();
    _loadPosts(resetList: true);
  }

  @override
  void didUpdateWidget(RecommendedPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Si le tag a changé, recharger les posts
    if (oldWidget.selectedTag != widget.selectedTag) {
      debugPrint('Tag changé: ${oldWidget.selectedTag} → ${widget.selectedTag}');
      _loadPosts(resetList: true);
    }
  }

  /// Charge les posts recommandés depuis l'API
  Future<void> _loadPosts({bool resetList = false, bool loadMore = false}) async {
    if (loadMore && _isLoadingMore) return;
    
    try {
      if (resetList) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _currentPage = 0;
        });
      } else if (loadMore) {
        setState(() {
          _isLoadingMore = true;
        });
      }

      // Déterminer l'offset
      final offset = resetList ? 0 : (_currentPage + 1) * _pageSize;
      
      // Appeler l'API des posts recommandés
      final response = await _getRecommendedPosts(
        tags: widget.selectedTag != 'Tous' ? [_convertTagToBackend(widget.selectedTag)] : [],
        limit: _pageSize,
        offset: offset,
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        
        // Extraire les posts de la réponse
        final postsData = data['posts'] as List? ?? [];
        List<Post> newPosts = postsData.map((postData) {
          return Post.fromJson(Map<String, dynamic>.from(postData));
        }).toList();

        // Mettre à jour les métadonnées
        final total = data['total'] ?? 0;
        final hasMore = data['has_more'] ?? false;

        setState(() {
          if (resetList) {
            _posts = newPosts;
            _currentPage = 0;
          } else {
            _posts.addAll(newPosts);
            _currentPage++;
          }
          
          _totalPosts = total;
          _hasMorePosts = hasMore;
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });

        debugPrint('✅ Posts recommandés chargés: ${newPosts.length} (total: ${_posts.length}/${total})');
      } else {
        throw Exception(response.error ?? 'Erreur inconnue');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement posts recommandés: $e');
      
      // Gestion spécifique selon le type d'erreur
      String errorMessage = _getErrorMessage(e.toString());
      
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = errorMessage;
        if (resetList) {
          _posts = [];
        }
      });
    }
  }

  /// Appelle l'endpoint des posts recommandés
  Future<ApiResponse<Map<String, dynamic>>> _getRecommendedPosts({
    List<String> tags = const [],
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Construire les paramètres de la requête
      final Map<String, String> queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      // Ajouter les tags s'ils sont spécifiés
      if (tags.isNotEmpty) {
        queryParams['tags'] = tags.join(',');
      }

      return await _apiService.get<Map<String, dynamic>>(
        '/posts/recommended',
        queryParams: queryParams,
      );
    } catch (e) {
      debugPrint('❌ Erreur API posts recommandés: $e');
      return ApiResponse.error('Erreur de connexion: $e');
    }
  }

  /// Convertit un nom de tag d'affichage en clé backend
  String _convertTagToBackend(String displayTag) {
    const Map<String, String> tagMapping = {
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
    
    return tagMapping[displayTag] ?? displayTag.toLowerCase();
  }

  /// Retourne un message d'erreur user-friendly
  String _getErrorMessage(String error) {
    if (error.contains('401') || error.contains('Authentication required')) {
      return 'Veuillez vous reconnecter';
    } else if (error.contains('404')) {
      return 'Aucun contenu trouvé pour cette catégorie';
    } else if (error.contains('500') || error.contains('Internal Server Error')) {
      return 'Problème temporaire du serveur';
    } else if (error.contains('Connection') || error.contains('Network')) {
      return 'Problème de connexion internet';
    } else if (error.contains('Failed to load posts')) {
      return 'Impossible de charger les posts pour cette catégorie';
    }
    
    return 'Erreur de chargement des posts';
  }

  /// État d'erreur avec options de récupération
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshPosts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Réessayer',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshPosts() async {
    await _loadPosts(resetList: true);
  }

  void _loadMorePosts() {
    if (_hasMorePosts && !_isLoadingMore && _posts.length >= _pageSize) {
      _loadPosts(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header avec informations sur le tag sélectionné
        if (widget.selectedTag != 'Tous' && !_isLoading && !_hasError)
          _buildTagHeader(),
        
        // Contenu principal
        if (_isLoading && _posts.isEmpty)
          _buildLoadingState()
        else if (_hasError && _posts.isEmpty)
          _buildErrorState()
        else if (_posts.isEmpty)
          _buildEmptyState()
        else
          _buildPostsGrid(),
      ],
    );
  }

  /// Header informatif pour les tags spécifiques
  Widget _buildTagHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Text(
            'Posts recommandés en ${widget.selectedTag}',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_totalPosts > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_totalPosts',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              widget.selectedTag == 'Tous' 
                  ? "Aucune recommandation disponible pour le moment."
                  : "Aucune publication recommandée pour ce tag.",
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsGrid() {
    return RefreshIndicator(
      onRefresh: _refreshPosts,
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          // Load more quand on arrive près de la fin
          if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.8) {
            _loadMorePosts();
          }
          return false;
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildMasonryGrid(_posts),
              
              // Indicateur de chargement pour plus de posts
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.black),
                  ),
                ),
              
              // Message fin de liste si plus de posts
              if (!_hasMorePosts && _posts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Vous avez vu tous les posts recommandés',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              // Espace final
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMasonryGrid(List<Post> posts) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: _ModernMasonryGrid(
        posts: posts,
        onPostTap: _navigateToPostDetail,
      ),
    );
  }

  /// 🎯 NAVIGATION VERS POST DETAIL PAGE
  void _navigateToPostDetail(Post post) {
    debugPrint('🎯 Navigation vers PostDetailPage: ${post.title} (ID: ${post.id})');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          postId: post.id,
          initialPost: post,
        ),
      ),
    );
  }
}

/// Layout masonry moderne avec métadonnées et actions
class _ModernMasonryGrid extends StatelessWidget {
  final List<Post> posts;
  final Function(Post) onPostTap;
  
  const _ModernMasonryGrid({
    required this.posts,
    required this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Grille à 2 colonnes pour plus d'espace pour les métadonnées
        final screenWidth = constraints.maxWidth;
        final itemWidth = (screenWidth - 16) / 2; // 2 colonnes avec 16px de gap
        
        return Column(
          children: _buildRows(itemWidth),
        );
      },
    );
  }

  List<Widget> _buildRows(double itemWidth) {
    final List<Widget> rows = [];
    
    for (int i = 0; i < posts.length; i += 2) {
      rows.add(_buildRow(itemWidth, i));
      if (i + 1 < posts.length) {
        rows.add(const SizedBox(height: 16));
      }
    }
    
    return rows;
  }

  Widget _buildRow(double itemWidth, int startIndex) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premier post
        if (startIndex < posts.length)
          Expanded(
            child: _buildPostCard(
              posts[startIndex], 
              itemWidth,
              _getRandomHeight(startIndex),
            ),
          ),
        
        const SizedBox(width: 16),
        
        // Deuxième post
        if (startIndex + 1 < posts.length)
          Expanded(
            child: _buildPostCard(
              posts[startIndex + 1], 
              itemWidth,
              _getRandomHeight(startIndex + 1),
            ),
          )
        else
          Expanded(child: Container()), // Espace vide si pas de deuxième post
      ],
    );
  }

  double _getRandomHeight(int index) {
    // Hauteurs variables pour créer l'effet masonry
    final heights = [200.0, 250.0, 180.0, 220.0, 240.0, 190.0];
    return heights[index % heights.length];
  }

  Widget _buildPostCard(Post post, double width, double imageHeight) {
    return GestureDetector(
      onTap: () => onPostTap(post),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image avec overlay pour le titre
            _buildPostImage(post, imageHeight),
            
            // Métadonnées et actions
            _buildPostMeta(post),
          ],
        ),
      ),
    );
  }

  Widget _buildPostImage(Post post, double height) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image de fond ou gradient
            _buildBackground(post),
            
            // Overlay gradient pour la lisibilité
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
            
            // Badge recommandé
            if (post.tags.contains('recommended'))
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Recommandé',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Icône de catégorie
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconFromTags(post.tags),
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            
            // Titre du post
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                post.title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.8),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostMeta(Post post) {
    return Consumer<PostsProvider>(
      builder: (context, postsProvider, _) {
        final likesCount = postsProvider.getLikesCount(post.id);
        final commentsCount = postsProvider.getCommentsCount(post.id);
        final isLiked = postsProvider.isLikedByUser(post.id);
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Créateur
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(post.authorAvatarFallback),
                    backgroundColor: Colors.grey[200],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorDisplayName,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          _formatTimeAgo(post.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Actions
              Row(
                children: [
                  _buildActionButton(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    '$likesCount',
                    isLiked ? Colors.red : Colors.grey[600]!,
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    Icons.mode_comment_outlined,
                    '$commentsCount',
                    Colors.grey[600]!,
                  ),
                  const Spacer(),
                  Icon(
                    Icons.bookmark_border,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String count, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        const SizedBox(width: 6),
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildBackground(Post post) {
    if (post.mediaUrl.isNotEmpty) {
      return Image.network(
        post.mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildGradientBackground(post);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildGradientBackground(post);
        },
      );
    }
    
    return _buildGradientBackground(post);
  }

  Widget _buildGradientBackground(Post post) {
    final gradients = [
      const LinearGradient(
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF43e97b), Color(0xFF38f9d7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFFfa709a), Color(0xFFfee140)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ];
    
    final gradientIndex = post.title.hashCode % gradients.length;
    
    return Container(
      decoration: BoxDecoration(
        gradient: gradients[gradientIndex.abs()],
      ),
    );
  }

  IconData _getIconFromTags(List<String> tags) {
    if (tags.isEmpty) return Icons.camera_alt;

    for (String tag in tags) {
      switch (tag.toLowerCase()) {
        case 'fitness':
        case 'musculation':
          return Icons.fitness_center;
        case 'yoga':
          return Icons.self_improvement;
        case 'wellness':
          return Icons.spa;
        case 'art':
          return Icons.palette;
        case 'musique':
        case 'music':
          return Icons.music_note;
        case 'cuisine':
        case 'food':
          return Icons.restaurant;
        case 'mode':
        case 'fashion':
          return Icons.style;
        case 'beaute':
        case 'beauté':
        case 'beauty':
          return Icons.face;
        default:
          continue;
      }
    }

    return Icons.camera_alt;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'maintenant';
    }
  }
}