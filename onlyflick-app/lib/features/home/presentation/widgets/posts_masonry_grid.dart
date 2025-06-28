// lib/features/posts/widgets/posts_masonry_grid.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/post_models.dart';

class PostsMasonryGrid extends StatelessWidget {
  final List<Post> posts;
  final Function(Post)? onPostTap;

  const PostsMasonryGrid({
    super.key,
    required this.posts,
    this.onPostTap,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(
        child: Text('Aucun post à afficher'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: CustomScrollView(
        slivers: [
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= posts.length) return null;
                
                final post = posts[index];
                return _buildPostItem(context, post, index);
              },
              childCount: posts.length,
            ),
          ),
          // Ajouter un padding en bas pour éviter que le contenu soit caché
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildPostItem(BuildContext context, Post post, int index) {
    // Détermine la taille du post selon sa position pour créer l'effet mosaïque
    final GridItemSize size = _getItemSize(index);
    
    return GestureDetector(
      onTap: () => onPostTap?.call(post),
      child: GridTile(
        child: _PostGridItem(
          post: post,
          size: size,
        ),
      ),
    );
  }

  GridItemSize _getItemSize(int index) {
    // Pattern pour créer la mosaïque comme dans la maquette
    const pattern = [
      GridItemSize.large,  // Post 1 - large (2x2)
      GridItemSize.normal, // teggzr - normal
      GridItemSize.normal, // Nature - normal  
      GridItemSize.wide,   // Art Digital - wide (2x1)
      GridItemSize.normal, // Street - normal
      GridItemSize.normal, // Fashion - normal
      GridItemSize.normal, // Food - normal
      GridItemSize.normal, // Travel - normal
      GridItemSize.normal, // Music - normal
    ];
    
    return pattern[index % pattern.length];
  }
}

enum GridItemSize { normal, large, wide }

class _PostGridItem extends StatefulWidget {
  final Post post;
  final GridItemSize size;

  const _PostGridItem({
    required this.post,
    required this.size,
  });

  @override
  State<_PostGridItem> createState() => _PostGridItemState();
}

class _PostGridItemState extends State<_PostGridItem> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: _buildGridItem(),
          ),
        );
      },
    );
  }

  Widget _buildGridItem() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          if (_isPressed)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image de fond ou gradient
            _buildBackground(),
            
            // Overlay sombre pour la lisibilité du texte
            _buildOverlay(),
            
            // Indicateur de type de contenu
            _buildContentIndicator(),
            
            // Titre du post
            _buildPostTitle(),
            
            // Overlay d'interaction au hover/press
            if (_isPressed) _buildInteractionOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    if (widget.post.mediaUrl.isNotEmpty) {
      return Image.network(
        widget.post.mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildGradientBackground();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildGradientBackground();
        },
      );
    }
    
    return _buildGradientBackground();
  }

  Widget _buildGradientBackground() {
    // Différents gradients selon l'index pour créer de la diversité
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
    
    final gradientIndex = widget.post.title.hashCode % gradients.length;
    
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
            Colors.black.withOpacity(0.7),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.4, 1.0],
        ),
      ),
    );
  }

  Widget _buildContentIndicator() {
    IconData icon;
    String contentType = _getContentType();
    
    switch (contentType) {
      case 'video':
        icon = Icons.play_circle_outline;
        break;
      case 'carousel':
        icon = Icons.collections;
        break;
      case 'audio':
        icon = Icons.audiotrack;
        break;
      default:
        icon = Icons.camera_alt;
    }

    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildPostTitle() {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Text(
        widget.post.title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: widget.size == GridItemSize.large ? 16 : 14,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              offset: const Offset(0, 1),
              blurRadius: 3,
            ),
          ],
        ),
        maxLines: widget.size == GridItemSize.large ? 2 : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildInteractionOverlay() {
    // Génère un nombre de likes factice basé sur l'ID du post pour la démo
    final fakeLikes = _generateFakeLikes();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.favorite_border,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '$fakeLikes',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Génère un nombre de likes factice pour la démo
  int _generateFakeLikes() {
    // Utilise l'ID du post et son titre pour générer un nombre cohérent
    final seed = widget.post.id.hashCode + widget.post.title.hashCode;
    final random = seed.abs();
    return 15 + (random % 500); // Entre 15 et 515 likes
  }

  String _getContentType() {
    // Logique simple pour déterminer le type de contenu
    // À adapter selon votre modèle de données
    if (widget.post.mediaUrl.contains('.mp4') || 
        widget.post.mediaUrl.contains('video')) {
      return 'video';
    } else if (widget.post.mediaUrl.contains('carousel') ||
               widget.post.title.toLowerCase().contains('carousel')) {
      return 'carousel';
    } else if (widget.post.mediaUrl.contains('.mp3') ||
               widget.post.title.toLowerCase().contains('music') ||
               widget.post.title.toLowerCase().contains('audio')) {
      return 'audio';
    }
    return 'image';
  }
}

// Extension pour adapter la grille selon la taille
extension on GridItemSize {
  int get gridWidth {
    switch (this) {
      case GridItemSize.large:
        return 2;
      case GridItemSize.wide:
        return 2;
      case GridItemSize.normal:
        return 1;
    }
  }
  
  int get gridHeight {
    switch (this) {
      case GridItemSize.large:
        return 2;
      case GridItemSize.wide:
        return 1;
      case GridItemSize.normal:
        return 1;
    }
  }
}