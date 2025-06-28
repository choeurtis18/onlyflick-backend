import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/posts_providers.dart';
import '../../../../../core/services/posts_service.dart';
import '../../../../core/models/post_models.dart' as models; // ===== ALIAS POUR ÉVITER CONFLITS =====

class ConnectedPostWidget extends StatefulWidget {
  final models.Post post; // ===== UTILISATION DE L'ALIAS =====
  final VoidCallback onLike;
  final Function(String) onComment;
  final Function(String) onError;

  const ConnectedPostWidget({
    super.key,
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onError,
  });

  @override
  State<ConnectedPostWidget> createState() => _ConnectedPostWidgetState();
}

class _ConnectedPostWidgetState extends State<ConnectedPostWidget>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  
  bool _isAddingComment = false;
  bool _showLikeAnimation = false;
  
  late AnimationController _likeAnimationController;
  late AnimationController _pulseAnimationController;
  
  late Animation<double> _likeScaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _likeScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _likeAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _handleAddComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isAddingComment = true;
    });

    final success = await widget.onComment(content);
    
    if (success) {
      _commentController.clear();
      _commentFocusNode.unfocus();
      HapticFeedback.lightImpact();
    } else {
      widget.onError('Erreur lors de l\'ajout du commentaire');
    }

    setState(() {
      _isAddingComment = false;
    });
  }

  void _handleDoubleTapLike() {
    widget.onLike();
    
    setState(() {
      _showLikeAnimation = true;
    });
    
    _likeAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showLikeAnimation = false;
          });
          _likeAnimationController.reset();
        }
      });
    });
    
    HapticFeedback.mediumImpact();
  }

  void _handleLikeTap() {
    widget.onLike();
    _pulseAnimationController.forward().then((_) {
      _pulseAnimationController.reverse();
    });
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PostsProvider>(
      builder: (context, postsProvider, _) {
        final likesCount = postsProvider.getLikesCount(widget.post.id);
        final isLiked = postsProvider.isLikedByUser(widget.post.id);
        final commentsCount = postsProvider.getCommentsCount(widget.post.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCleanHeader(),
              _buildCleanImage(),
              _buildCleanActions(isLiked, likesCount, commentsCount),
              _buildCleanDescription(),
              _buildCleanCommentsSection(postsProvider),
              _buildCleanAddCommentSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCleanHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // ===== AVATAR AVEC VRAIE URL =====
          CircleAvatar(
            backgroundImage: NetworkImage(
              widget.post.authorAvatarFallback, // ===== UTILISATION DU VRAI AVATAR =====
            ),
            radius: 18,
          ),
          const SizedBox(width: 12),
          
          // Info utilisateur épurée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.post.authorDisplayName, // ===== UTILISATION DU VRAI USERNAME =====
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black,
                      ),
                    ),
                    // ===== BADGE CRÉATEUR =====
                    if (widget.post.isFromCreator) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Créateur',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    // ===== BADGE PREMIUM =====
                    if (widget.post.isSubscriberOnly) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Premium',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  _getTimeAgo(widget.post.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Menu épuré
          IconButton(
            onPressed: () => _showOptionsMenu(context),
            icon: Icon(Icons.more_horiz, color: Colors.grey[600], size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildCleanImage() {
    return GestureDetector(
      onDoubleTap: _handleDoubleTapLike,
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.width * 0.75, // Ratio plus moderne
        color: Colors.grey[100],
        child: Stack(
          children: [
            // Image
            widget.post.mediaUrl.isNotEmpty
                ? Image.network(
                    widget.post.mediaUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Center(
                          child: Icon(Icons.broken_image, 
                                     size: 40, color: Colors.grey[400]),
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(Icons.image, size: 40, color: Colors.grey[400]),
                    ),
                  ),
            
            // Animation de like
            if (_showLikeAnimation)
              Center(
                child: AnimatedBuilder(
                  animation: _likeScaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _likeScaleAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 32,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanActions(bool isLiked, int likesCount, int commentsCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Like button
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: GestureDetector(
                  onTap: _handleLikeTap,
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.black,
                    size: 24,
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(width: 16),
          
          // Comment button
          GestureDetector(
            onTap: () => _commentFocusNode.requestFocus(),
            child: const Icon(
              Icons.mode_comment_outlined,
              color: Colors.black,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Share button
          const Icon(
            Icons.send_outlined,
            color: Colors.black,
            size: 22,
          ),
          
          const Spacer(),
          
          // Bookmark button
          const Icon(
            Icons.bookmark_border,
            color: Colors.black,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildCleanDescription() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Likes count
          Consumer<PostsProvider>(
            builder: (context, postsProvider, _) {
              final likesCount = postsProvider.getLikesCount(widget.post.id);
              if (likesCount > 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$likesCount J\'aime${likesCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          
          // Description
          if (widget.post.description.isNotEmpty) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${widget.post.authorDisplayName} ', // ===== VRAI USERNAME =====
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                  TextSpan(
                    text: widget.post.description,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          // Title si présent
          if (widget.post.title.isNotEmpty) ...[
            Text(
              widget.post.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  Widget _buildCleanCommentsSection(PostsProvider postsProvider) {
    return FutureBuilder<List<models.Comment>>( // ===== UTILISATION DE L'ALIAS =====
      future: postsProvider.getComments(widget.post.id),
      builder: (context, snapshot) {
        final comments = snapshot.data ?? [];
        
        if (comments.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Lien pour voir tous les commentaires
              if (comments.length > 1) ...[
                GestureDetector(
                  onTap: () => _showCommentsModal(context, comments),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Voir les ${comments.length} commentaires',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
              
              // Commentaire le plus récent
              _buildCompactComment(comments.last),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactComment(models.Comment comment) { // ===== UTILISATION DE L'ALIAS =====
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${comment.authorDisplayName} ', // ===== VRAI USERNAME DU COMMENTAIRE =====
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black,
                fontSize: 14,
              ),
            ),
            TextSpan(
              text: comment.content,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanAddCommentSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.post.authorAvatarFallback),
            radius: 14,
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: InputDecoration(
                hintText: 'Ajouter un commentaire...',
                hintStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (_) => _handleAddComment(),
            ),
          ),
          
          if (_isAddingComment)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            GestureDetector(
              onTap: _handleAddComment,
              child: Text(
                'Publier',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Signaler'),
              onTap: () {
                Navigator.pop(context);
                widget.onError('Fonctionnalité de signalement à venir');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager'),
              onTap: () {
                Navigator.pop(context);
                widget.onError('Fonctionnalité de partage à venir');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCommentsModal(BuildContext context, List<models.Comment> comments) { // ===== UTILISATION DE L'ALIAS =====
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Commentaires',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${comments.length}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 24),
              
              // Comments list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return _buildModalCommentItem(comment);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModalCommentItem(models.Comment comment) { // ===== UTILISATION DE L'ALIAS =====
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(
              comment.authorAvatarFallback, // ===== VRAI AVATAR DU COMMENTAIRE =====
            ),
            radius: 16,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${comment.authorDisplayName} ', // ===== VRAI USERNAME DU COMMENTAIRE =====
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: comment.content,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.timeAgo, // ===== UTILISATION DE LA MÉTHODE DU MODÈLE =====
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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