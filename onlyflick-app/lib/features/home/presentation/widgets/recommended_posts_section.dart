// lib/features/posts/widgets/recommended_posts_section.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/post_models.dart';
import '../../../../core/services/api_service.dart';

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

      // debugPrint('🔍 Chargement posts recommandés pour tag: ${widget.selectedTag}');

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

      // debugPrint('📡 Requête posts recommandés: /posts/recommended avec params: $queryParams');

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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                const SizedBox(width: 12),
                // Bouton pour revenir aux posts généraux si on a un problème avec un tag spécifique
                if (widget.selectedTag != 'Tous')
                  TextButton(
                    onPressed: () {
                      // Simuler la sélection du tag "Tous"
                      debugPrint('Tentative de retour aux posts généraux');
                      // Note: En réalité, ceci devrait déclencher un callback vers le parent
                      // pour changer le tag sélectionné
                    },
                    child: Text(
                      'Voir tous les posts',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.blue[600],
                      ),
                    ),
                  ),
              ],
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
            const SizedBox(height: 8),
            Text(
              widget.selectedTag == 'Tous'
                  ? "Essayez de sélectionner une catégorie spécifique."
                  : "Essayez de sélectionner une autre catégorie.",
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 12,
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
      child: _MasonryGridLayout(posts: posts),
    );
  }
}

/// Layout en grille masonry pour afficher les posts
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
              
              // Indicateur de type de contenu BASÉ SUR LES TAGS
              _buildContentIndicator(post),
              
              // Titre du post
              _buildPostTitle(post, isLarge),
              
              // Badge pour posts recommandés
              if (isLarge)
                _buildRecommendedBadge(),
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

  /// NOUVELLE MÉTHODE : Indicateur basé sur les TAGS du post
  Widget _buildContentIndicator(Post post) {
    IconData icon;
    Color iconColor = Colors.white;
    
    // Déterminer l'icône basée sur les TAGS du post au lieu du type de média
    icon = _getIconFromTags(post, post.tags);

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
          color: iconColor,
          size: 12,
        ),
      ),
    );
  }

  /// NOUVELLE MÉTHODE : Détermine l'icône à afficher selon les tags du post
  IconData _getIconFromTags(Post post, List<String> tags) {
    // Si pas de tags, utiliser une icône générique
    if (tags.isEmpty) {
      return Icons.camera_alt;
    }

    // Parcourir les tags et retourner la première icône correspondante
    for (String tag in tags) {
      switch (tag.toLowerCase()) {
        // Tags fitness et sport
        case 'fitness':
        case 'musculation':
          return Icons.fitness_center;
        
        case 'yoga':
          return Icons.self_improvement;
        
        // Tags bien-être
        case 'wellness':
          return Icons.spa;
        
        // Tags créatifs
        case 'art':
          return Icons.palette;
        
        case 'musique':
        case 'music':
          return Icons.music_note;
        
        case 'diy':
          return Icons.handyman;
        
        // Tags lifestyle
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
        
        // Tags génériques
        case 'photo':
        case 'photography':
          return Icons.camera_alt;
        
        case 'video':
          return Icons.videocam;
        
        case 'travel':
          return Icons.flight;
        
        default:
          continue; // Continuer vers le tag suivant
      }
    }

    // Si aucun tag reconnu, essayer de deviner depuis le titre
    return _getIconFromTitle(post.title, tags.isNotEmpty ? tags.first : '');
  }

  /// NOUVELLE MÉTHODE : Fallback - essayer de deviner l'icône depuis le titre
  IconData _getIconFromTitle(String title, String firstTag) {
    final lowerText = (title + ' ' + firstTag).toLowerCase();
    
    if (lowerText.contains('workout') || 
        lowerText.contains('fitness') || 
        lowerText.contains('exercise') ||
        lowerText.contains('training') ||
        lowerText.contains('push') ||
        lowerText.contains('squat') ||
        lowerText.contains('transformation')) {
      return Icons.fitness_center;
    }
    
    if (lowerText.contains('yoga') || 
        lowerText.contains('meditation') ||
        lowerText.contains('zen')) {
      return Icons.self_improvement;
    }
    
    if (lowerText.contains('music') || 
        lowerText.contains('studio') ||
        lowerText.contains('song') ||
        lowerText.contains('sound')) {
      return Icons.music_note;
    }
    
    if (lowerText.contains('food') || 
        lowerText.contains('recipe') ||
        lowerText.contains('cook') ||
        lowerText.contains('boeuf') ||
        lowerText.contains('cuisine')) {
      return Icons.restaurant;
    }
    
    if (lowerText.contains('style') || 
        lowerText.contains('dress') ||
        lowerText.contains('look') ||
        lowerText.contains('outfit')) {
      return Icons.style;
    }
    
    if (lowerText.contains('morning') || 
        lowerText.contains('routine') ||
        lowerText.contains('wellness') ||
        lowerText.contains('equilibre')) {
      return Icons.spa;
    }
    
    if (lowerText.contains('art') || 
        lowerText.contains('paint') ||
        lowerText.contains('creative')) {
      return Icons.palette;
    }
    
    // Icône par défaut
    return Icons.camera_alt;
  }

  Widget _buildRecommendedBadge() {
    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              color: Colors.white,
              size: 10,
            ),
            const SizedBox(width: 2),
            Text(
              'Recommandé',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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

  void _onPostTap(Post post) {
    // TODO: Naviguer vers le détail du post
    debugPrint('Tap sur le post recommandé: ${post.title} avec tags: ${post.tags}');
  }
}