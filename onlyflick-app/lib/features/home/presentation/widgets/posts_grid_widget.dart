// lib/features/search/presentation/widgets/posts_grid_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/search_models.dart';

/// Widget pour afficher une grille de posts style Instagram
class PostsGridWidget extends StatefulWidget {
  final List<PostWithDetails> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;
  final Function(PostWithDetails) onPostTap;
  final Function(PostWithDetails)? onPostLike;
  final Function(PostWithDetails)? onPostShare;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final EdgeInsets? padding;
  final bool showOverlays;
  final bool showAuthor;

  const PostsGridWidget({
    super.key,
    required this.posts,
    required this.hasMore,
    required this.isLoadingMore,
    required this.onLoadMore,
    required this.onPostTap,
    this.onPostLike,
    this.onPostShare,
    this.crossAxisCount = 3,
    this.mainAxisSpacing = 2.0,
    this.crossAxisSpacing = 2.0,
    this.padding,
    this.showOverlays = true,
    this.showAuthor = false,
  });

  @override
  State<PostsGridWidget> createState() => _PostsGridWidgetState();
}

class _PostsGridWidgetState extends State<PostsGridWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.hasMore && !widget.isLoadingMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      controller: _scrollController,
      padding: widget.padding ?? const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        childAspectRatio: 1.0,
      ),
      itemCount: widget.posts.length + (widget.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= widget.posts.length) {
          return _buildLoadingTile();
        }

        final post = widget.posts[index];
        return PostGridTile(
          post: post,
          onTap: () => widget.onPostTap(post),
          onLike: widget.onPostLike != null ? () => widget.onPostLike!(post) : null,
          onShare: widget.onPostShare != null ? () => widget.onPostShare!(post) : null,
          showOverlays: widget.showOverlays,
          showAuthor: widget.showAuthor,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun post trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez avec d\'autres filtres',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingTile() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.black,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}

/// Widget pour une tuile de post individuelle
class PostGridTile extends StatefulWidget {
  final PostWithDetails post;
  final VoidCallback onTap;
  final VoidCallback? onLike;
  final VoidCallback? onShare;
  final bool showOverlays;
  final bool showAuthor;

  const PostGridTile({
    super.key,
    required this.post,
    required this.onTap,
    this.onLike,
    this.onShare,
    this.showOverlays = true,
    this.showAuthor = false,
  });

  @override
  State<PostGridTile> createState() => _PostGridTileState();
}

class _PostGridTileState extends State<PostGridTile> 
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
            onTap: widget.onTap,
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: _isPressed ? [] : [
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
                  children: [
                    _buildImage(),
                    if (widget.showOverlays) _buildOverlays(),
                    if (widget.showAuthor) _buildAuthorOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage() {
    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: widget.post.mediaUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.grey[400],
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Colors.grey[500],
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                'Image\nindisponible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverlays() {
    return Stack(
      children: [
        // Gradient overlay pour améliorer la lisibilité
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        
        // Tag en haut à gauche
        if (widget.post.tags.isNotEmpty) _buildTopLeftTag(),
        
        // Visibilité en haut à droite
        if (widget.post.isSubscriberOnly) _buildVisibilityBadge(),
        
        // Likes en bas à droite
        _buildBottomRightStats(),
      ],
    );
  }

  Widget _buildTopLeftTag() {
    final tag = widget.post.tags.first;
    return Positioned(
      top: 6,
      left: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _getTagColor(tag).withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tag.emoji,
              style: const TextStyle(fontSize: 10),
            ),
            if (widget.post.tags.length > 1) ...[
              const SizedBox(width: 2),
              Text(
                '+${widget.post.tags.length - 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilityBadge() {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(
          Icons.lock,
          color: Colors.white,
          size: 12,
        ),
      ),
    );
  }

  Widget _buildBottomRightStats() {
    return Positioned(
      bottom: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.post.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.post.isLiked ? Colors.red : Colors.white,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              _formatCount(widget.post.likesCount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (widget.post.commentsCount > 0) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.mode_comment_outlined,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 2),
              Text(
                _formatCount(widget.post.commentsCount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: Colors.white,
              backgroundImage: widget.post.author.avatarUrl != null
                  ? CachedNetworkImageProvider(widget.post.author.avatarUrl!)
                  : null,
              child: widget.post.author.avatarUrl == null
                  ? Text(
                      widget.post.author.firstName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.post.author.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.post.timeAgo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.post.author.isCreator)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified,
                  color: Colors.white,
                  size: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getTagColor(TagCategory tag) {
    switch (tag) {
      case TagCategory.art:
        return Colors.purple;
      case TagCategory.music:
        return Colors.pink;
      case TagCategory.sport:
        return Colors.green;
      case TagCategory.cinema:
        return Colors.red;
      case TagCategory.tech:
        return Colors.blue;
      case TagCategory.fashion:
        return Colors.orange;
      case TagCategory.food:
        return Colors.amber;
      case TagCategory.travel:
        return Colors.teal;
      case TagCategory.gaming:
        return Colors.indigo;
      case TagCategory.lifestyle:
        return Colors.brown;
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}

/// Widget de grille compacte pour aperçus
class CompactPostsGrid extends StatelessWidget {
  final List<PostWithDetails> posts;
  final Function(PostWithDetails) onPostTap;
  final int maxPosts;

  const CompactPostsGrid({
    super.key,
    required this.posts,
    required this.onPostTap,
    this.maxPosts = 9,
  });

  @override
  Widget build(BuildContext context) {
    final displayPosts = posts.take(maxPosts).toList();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: displayPosts.length,
      itemBuilder: (context, index) {
        final post = displayPosts[index];
        return PostGridTile(
          post: post,
          onTap: () => onPostTap(post),
          showOverlays: false,
          showAuthor: false,
        );
      },
    );
  }
}

/// Widget de grille avec mode sélection multiple
class SelectablePostsGrid extends StatefulWidget {
  final List<PostWithDetails> posts;
  final Function(List<PostWithDetails>) onSelectionChanged;
  final bool selectionMode;

  const SelectablePostsGrid({
    super.key,
    required this.posts,
    required this.onSelectionChanged,
    required this.selectionMode,
  });

  @override
  State<SelectablePostsGrid> createState() => _SelectablePostsGridState();
}

class _SelectablePostsGridState extends State<SelectablePostsGrid> {
  final Set<int> _selectedPostIds = {};

  @override
  void didUpdateWidget(SelectablePostsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selectionMode) {
      _selectedPostIds.clear();
    }
  }

  void _toggleSelection(PostWithDetails post) {
    setState(() {
      if (_selectedPostIds.contains(post.id)) {
        _selectedPostIds.remove(post.id);
      } else {
        _selectedPostIds.add(post.id);
      }
    });

    final selectedPosts = widget.posts
        .where((post) => _selectedPostIds.contains(post.id))
        .toList();
    widget.onSelectionChanged(selectedPosts);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: widget.posts.length,
      itemBuilder: (context, index) {
        final post = widget.posts[index];
        final isSelected = _selectedPostIds.contains(post.id);

        return GestureDetector(
          onTap: widget.selectionMode 
              ? () => _toggleSelection(post)
              : () {}, // Handle normal tap
          child: Stack(
            children: [
              PostGridTile(
                post: post,
                onTap: () => widget.selectionMode 
                    ? _toggleSelection(post)
                    : null,
                showOverlays: !widget.selectionMode,
              ),
              if (widget.selectionMode)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              if (widget.selectionMode)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blue : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}