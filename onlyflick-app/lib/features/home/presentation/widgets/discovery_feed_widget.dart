// lib/features/search/presentation/widgets/discovery_feed_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/models/search_models.dart';

/// Widget pour afficher le feed de découverte style Instagram
class DiscoveryFeedWidget extends StatefulWidget {
  final List<PostWithDetails> posts;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isRefreshing;
  final VoidCallback onLoadMore;
  final Future<void> Function() onRefresh;
  final Function(PostWithDetails) onPostTap;
  final Function(PostWithDetails) onLike;
  final Function(PostWithDetails)? onComment;
  final Function(PostWithDetails)? onShare;
  final Function(UserSearchResult)? onAuthorTap;
  final EdgeInsets? padding;

  const DiscoveryFeedWidget({
    super.key,
    required this.posts,
    required this.hasMore,
    required this.isLoadingMore,
    required this.isRefreshing,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onPostTap,
    required this.onLike,
    this.onComment,
    this.onShare,
    this.onAuthorTap,
    this.padding,
  });

  @override
  State<DiscoveryFeedWidget> createState() => _DiscoveryFeedWidgetState();
}

class _DiscoveryFeedWidgetState extends State<DiscoveryFeedWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 300) {
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
    if (widget.posts.isEmpty && !widget.isRefreshing) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: Colors.black,
      backgroundColor: Colors.white,
      child: ListView.separated(
        controller: _scrollController,
        padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget.posts.length + (widget.hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index >= widget.posts.length) {
            return _buildLoadingCard();
          }

          final post = widget.posts[index];
          return DiscoveryPostCard(
            post: post,
            onTap: () => widget.onPostTap(post),
            onLike: () => widget.onLike(post),
            onComment: widget.onComment != null ? () => widget.onComment!(post) : null,
            onShare: widget.onShare != null ? () => widget.onShare!(post) : null,
            onAuthorTap: widget.onAuthorTap != null ? () => widget.onAuthorTap!(post.author) : null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.explore_outlined,
                size: 80,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 24),
              Text(
                'Rien à découvrir pour le moment',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Tirez vers le bas pour actualiser\nou ajustez vos préférences',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tirez pour actualiser',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Colors.black,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 16),
          Text(
            'Chargement de nouveaux posts...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget pour une carte de post individuelle dans le feed
class DiscoveryPostCard extends StatefulWidget {
  final PostWithDetails post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onAuthorTap;

  const DiscoveryPostCard({
    super.key,
    required this.post,
    required this.onTap,
    required this.onLike,
    this.onComment,
    this.onShare,
    this.onAuthorTap,
  });

  @override
  State<DiscoveryPostCard> createState() => _DiscoveryPostCardState();
}

class _DiscoveryPostCardState extends State<DiscoveryPostCard> 
    with TickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late AnimationController _scaleAnimationController;
  late Animation<double> _likeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isLiked = false;
  int _likeCount = 0;

  @override
  void initState() {
    super.initState();
    
    _isLiked = widget.post.isLiked;
    _likeCount = widget.post.likesCount;
    
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _likeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    _scaleAnimationController.dispose();
    super.dispose();
  }

  void _onLikePressed() {
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    if (_isLiked) {
      _likeAnimationController.forward().then((_) {
        _likeAnimationController.reverse();
      });
    }

    widget.onLike();
  }

  void _onDoubleTap() {
    if (!_isLiked) {
      _onLikePressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildImage(),
                _buildActions(),
                _buildContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onAuthorTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[200],
              backgroundImage: widget.post.author.avatarUrl != null
                  ? CachedNetworkImageProvider(widget.post.author.avatarUrl!)
                  : null,
              child: widget.post.author.avatarUrl == null
                  ? Text(
                      widget.post.author.firstName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: widget.onAuthorTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.post.author.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      if (widget.post.author.isCreator) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        widget.post.author.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.post.timeAgo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _buildMoreButton(),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: _onDoubleTap,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: CachedNetworkImage(
              imageUrl: widget.post.mediaUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.grey,
                    strokeWidth: 2,
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
                      size: 48,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image indisponible',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.post.tags.isNotEmpty) _buildTagsOverlay(),
          if (widget.post.isSubscriberOnly) _buildSubscriberBadge(),
        ],
      ),
    );
  }

  Widget _buildTagsOverlay() {
    return Positioned(
      top: 12,
      left: 12,
      child: Wrap(
        spacing: 6,
        children: widget.post.tags.take(3).map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getTagColor(tag).withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tag.emoji,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 4),
                Text(
                  tag.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSubscriberBadge() {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              color: Colors.white,
              size: 14,
            ),
            SizedBox(width: 4),
            Text(
              'Abonnés',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _onLikePressed,
            child: AnimatedBuilder(
              animation: _likeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _likeAnimation.value,
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : Colors.black,
                    size: 28,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: widget.onComment,
            child: const Icon(
              Icons.mode_comment_outlined,
              color: Colors.black,
              size: 26,
            ),
          ),
          const SizedBox(width: 20),
          GestureDetector(
            onTap: widget.onShare,
            child: const Icon(
              Icons.send_outlined,
              color: Colors.black,
              size: 24,
            ),
          ),
          const Spacer(),
          _buildStatsButton(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_likeCount > 0) ...[
            Text(
              '${_formatCount(_likeCount)} j\'aime${_likeCount > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
          ],
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: widget.post.author.username,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const TextSpan(text: '  '),
                TextSpan(
                  text: widget.post.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          if (widget.post.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              widget.post.description,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.3,
              ),
            ),
          ],
          if (widget.post.commentsCount > 0) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: widget.onComment,
              child: Text(
                'Voir les ${widget.post.commentsCount} commentaire${widget.post.commentsCount > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoreButton() {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_horiz,
        color: Colors.black,
      ),
      onSelected: (value) {
        switch (value) {
          case 'share':
            widget.onShare?.call();
            break;
          case 'report':
            _showReportDialog();
            break;
          case 'copy':
            _copyLink();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 12),
              Text('Partager'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              Icon(Icons.link, size: 20),
              SizedBox(width: 12),
              Text('Copier le lien'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag, size: 20),
              SizedBox(width: 12),
              Text('Signaler'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsButton() {
    if (widget.post.viewsCount == 0) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () => _showStatsDialog(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility,
              size: 14,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              _formatCount(widget.post.viewsCount),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
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

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signaler ce post'),
        content: const Text('Voulez-vous signaler ce contenu comme inapproprié ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post signalé')),
              );
            },
            child: const Text('Signaler'),
          ),
        ],
      ),
    );
  }

  void _copyLink() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié dans le presse-papiers')),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistiques du post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow(Icons.favorite, 'Likes', _likeCount),
            const SizedBox(height: 8),
            _buildStatRow(Icons.mode_comment, 'Commentaires', widget.post.commentsCount),
            const SizedBox(height: 8),
            _buildStatRow(Icons.visibility, 'Vues', widget.post.viewsCount),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, int count) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ${_formatCount(count)}',
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}

/// Widget compact pour aperçu du feed de découverte
class CompactDiscoveryFeed extends StatelessWidget {
  final List<PostWithDetails> posts;
  final Function(PostWithDetails) onPostTap;
  final int maxPosts;

  const CompactDiscoveryFeed({
    super.key,
    required this.posts,
    required this.onPostTap,
    this.maxPosts = 3,
  });

  @override
  Widget build(BuildContext context) {
    final displayPosts = posts.take(maxPosts).toList();
    
    return Column(
      children: displayPosts.map((post) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: DiscoveryPostCard(
            post: post,
            onTap: () => onPostTap(post),
            onLike: () {}, // Pas d'action dans la version compacte
          ),
        );
      }).toList(),
    );
  }
}