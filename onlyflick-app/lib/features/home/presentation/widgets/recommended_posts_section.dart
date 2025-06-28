// lib/features/posts/widgets/recommended_posts_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/post_models.dart';
import '../../../../core/services/tags_service.dart';

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
  List<Post> _posts = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Pagination
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMorePosts = false;
  bool _isLoadingMore = false;

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
      print('Tag changé: ${oldWidget.selectedTag} → ${widget.selectedTag}');
      _loadPosts(resetList: true);
    }
  }

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

      final response = await TagsService.getPostsByTag(
        widget.selectedTag,
        limit: _pageSize,
        offset: resetList ? 0 : (_currentPage + 1) * _pageSize,
      );

      if (response['posts'] != null) {
        // Convertir les Map en objets Post
        List<Post> newPosts = (response['posts'] as List).map((postData) {
          return Post.fromJson(Map<String, dynamic>.from(postData));
        }).toList();

        setState(() {
          if (resetList) {
            _posts = newPosts;
            _currentPage = 0;
          } else {
            _posts.addAll(newPosts);
            _currentPage++;
          }
          
          _hasMorePosts = response['has_more'] ?? false;
          _isLoading = false;
          _isLoadingMore = false;
          _hasError = false;
        });

        print('Posts chargés: ${newPosts.length} (total: ${_posts.length})');
      }
    } catch (e) {
      print('Erreur chargement posts: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _hasError = true;
        _errorMessage = 'Erreur de chargement des posts';
        if (resetList) {
          _posts = [];
        }
      });
    }
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

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }

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
                  : "Aucune publication pour ce tag.",
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
      child: _MasonryGridLayout(posts: posts),
    );
  }
}

class _MasonryGridLayout extends StatelessWidget {
  final List<Post> posts;
  
  const _MasonryGridLayout({required this.posts});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final itemWidth = (screenWidth - 4) / 3; // 3 colonnes avec 2px de gap
        
        return Column(
          children: _buildRows(itemWidth),
        );
      },
    );
  }

  List<Widget> _buildRows(double itemWidth) {
    final List<Widget> rows = [];
    int index = 0;
    
    while (index < posts.length) {
      // Pattern inspiré de la maquette Instagram
      if (index == 0 && posts.length > 2) {
        // Première ligne: un grand item (2x2) + deux normaux
        rows.add(_buildFirstRow(itemWidth, index));
        index += 3;
      } else if (index > 0 && index + 1 < posts.length && (index - 3) % 6 == 0) {
        // Ligne avec un item large (2x1)
        rows.add(_buildWideRow(itemWidth, index));
        index += 2;
      } else {
        // Ligne normale avec 3 items
        rows.add(_buildNormalRow(itemWidth, index));
        index += 3;
      }
    }
    
    return rows;
  }

  Widget _buildFirstRow(double itemWidth, int startIndex) {
    return SizedBox(
      height: itemWidth * 2 + 2, // Double hauteur + gap
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item large (2x2)
          if (startIndex < posts.length)
            _buildPostItem(
              posts[startIndex], 
              itemWidth * 2 + 2, // Double largeur + gap
              itemWidth * 2 + 2, // Double hauteur + gap
              true, // isLarge
            ),
          
          const SizedBox(width: 2),
          
          // Colonne droite avec deux items normaux
          Expanded(
            child: Column(
              children: [
                if (startIndex + 1 < posts.length)
                  _buildPostItem(
                    posts[startIndex + 1], 
                    itemWidth, 
                    itemWidth,
                    false,
                  ),
                
                const SizedBox(height: 2),
                
                if (startIndex + 2 < posts.length)
                  _buildPostItem(
                    posts[startIndex + 2], 
                    itemWidth, 
                    itemWidth,
                    false,
                  )
                else
                  Container(
                    height: itemWidth,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideRow(double itemWidth, int startIndex) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      height: itemWidth,
      child: Row(
        children: [
          // Item wide (2x1)
          if (startIndex < posts.length)
            _buildPostItem(
              posts[startIndex], 
              itemWidth * 2 + 2, // Double largeur + gap
              itemWidth,
              false,
            ),
          
          const SizedBox(width: 2),
          
          // Item normal
          if (startIndex + 1 < posts.length)
            _buildPostItem(
              posts[startIndex + 1], 
              itemWidth, 
              itemWidth,
              false,
            ),
        ],
      ),
    );
  }

  Widget _buildNormalRow(double itemWidth, int startIndex) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      height: itemWidth,
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            if (startIndex + i < posts.length)
              _buildPostItem(
                posts[startIndex + i], 
                itemWidth, 
                itemWidth,
                false,
              )
            else
              Container(
                width: itemWidth,
                height: itemWidth,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPostItem(Post post, double width, double height, bool isLarge) {
    return GestureDetector(
      onTap: () => _onPostTap(post),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image de fond ou gradient
              _buildBackground(post),
              
              // Overlay sombre pour la lisibilité
              _buildOverlay(),
              
              // Indicateur de type de contenu
              _buildContentIndicator(post),
              
              // Titre du post
              _buildPostTitle(post, isLarge),
            ],
          ),
        ),
      ),
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
    // Différents gradients selon le post pour créer de la diversité
    final gradients = [
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
      const LinearGradient(
        colors: [Color(0xFFa8edea), Color(0xFFfed6e3)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      const LinearGradient(
        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.5, 1.0],
        ),
      ),
    );
  }

  Widget _buildContentIndicator(Post post) {
    IconData icon;
    String contentType = _getContentType(post);
    
    switch (contentType) {
      case 'video':
        icon = Icons.videocam;
        break;
      case 'carousel':
        icon = Icons.collections;
        break;
      case 'audio':
        icon = Icons.music_note;
        break;
      default:
        icon = Icons.camera_alt;
    }

    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }

  Widget _buildPostTitle(Post post, bool isLarge) {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Text(
        post.title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: isLarge ? 16 : 14,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        maxLines: isLarge ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  String _getContentType(Post post) {
    // Logique simple pour déterminer le type de contenu
    if (post.mediaUrl.contains('.mp4') || 
        post.mediaUrl.contains('video')) {
      return 'video';
    } else if (post.mediaUrl.contains('carousel') ||
               post.title.toLowerCase().contains('carousel')) {
      return 'carousel';
    } else if (post.mediaUrl.contains('.mp3') ||
               post.title.toLowerCase().contains('music') ||
               post.title.toLowerCase().contains('audio')) {
      return 'audio';
    }
    return 'image';
  }

  void _onPostTap(Post post) {
    // TODO: Naviguer vers le détail du post
    debugPrint('Tap sur le post: ${post.title}');
  }
}