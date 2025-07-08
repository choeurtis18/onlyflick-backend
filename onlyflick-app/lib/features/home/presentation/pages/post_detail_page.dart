// lib/features/posts/presentation/pages/post_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/post_models.dart';
import '../../../../core/providers/posts_providers.dart';
import '../../../../core/services/posts_service.dart';
import '../../../../core/models/report_models.dart'; // ✅ AJOUT
import '../../../home/presentation/widgets/report_dialog.dart'; // ✅ AJOUT
import '../pages/public_profile_page.dart';

/// Page de détail d'un post avec design moderne (style TikTok/Instagram)
class PostDetailPage extends StatefulWidget {
  final int postId;
  final Post? initialPost;

  const PostDetailPage({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage>
    with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  // État du post
  Post? _post;
  bool _isLoading = false;
  bool _isLoadingComments = false;
  bool _isAddingComment = false;
  String? _error;

  // Commentaires
  List<Comment> _comments = [];
  bool _showCommentsSheet = false;

  // Animations
  late AnimationController _likeAnimationController;
  late Animation<double> _likeScaleAnimation;
  bool _showLikeAnimation = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializePost();
    _loadComments();
  }

  void _initializeAnimations() {
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _likeScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _likeAnimationController,
      curve: Curves.elasticOut,
    ));
  }

  void _initializePost() {
    if (widget.initialPost != null) {
      _post = widget.initialPost;
    } else {
      _loadPost();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  /// 🔄 CHARGEMENT DU POST
  Future<void> _loadPost() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final postService = PostsService();
      final result = await postService.getPostById(widget.postId);

      if (result.isSuccess && result.data != null) {
        setState(() {
          _post = result.data!;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.error ?? 'Erreur lors du chargement du post';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur de connexion';
        _isLoading = false;
      });
    }
  }

  /// 💬 CHARGEMENT DES COMMENTAIRES
  Future<void> _loadComments({bool refresh = false}) async {
    if (_isLoadingComments) return;

    setState(() {
      _isLoadingComments = true;
      if (refresh) {
        _comments.clear();
      }
    });

    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      final comments = await postsProvider.getComments(widget.postId);

      setState(() {
        if (refresh) {
          _comments = comments;
        } else {
          _comments.addAll(comments);
        }
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }

  /// ❤️ GESTION DU LIKE
  Future<void> _handleLike() async {
    if (_post == null) return;

    HapticFeedback.lightImpact();
    
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

    final postsProvider = Provider.of<PostsProvider>(context, listen: false);
    await postsProvider.toggleLike(_post!.id);
  }

  /// 💬 AJOUT D'UN COMMENTAIRE
  Future<void> _handleAddComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _isAddingComment) return;

    setState(() => _isAddingComment = true);

    try {
      final postsProvider = Provider.of<PostsProvider>(context, listen: false);
      final success = await postsProvider.addComment(_post!.id, content);

      if (success) {
        _commentController.clear();
        _commentFocusNode.unfocus();
        await _loadComments(refresh: true);
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _showSnackBar('Erreur lors de l\'ajout du commentaire', isError: true);
    } finally {
      setState(() => _isAddingComment = false);
    }
  }

  /// 🎯 NAVIGATION VERS PROFIL
  void _navigateToUserProfile(int userId, String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PublicProfilePage(
          userId: userId,
          username: username.isNotEmpty ? username : 'user$userId',
        ),
      ),
    );
  }

  /// 🚩 SIGNALEMENT DU POST - NOUVELLE IMPLÉMENTATION
  void _showReportDialog() {
    if (_post == null) return;
    
    // Construire le titre pour l'aperçu
    String contentPreview = _post!.title.isNotEmpty 
        ? _post!.title 
        : _post!.description.isNotEmpty 
            ? _post!.description 
            : 'Post de ${_post!.authorDisplayName}';
    
    // Limiter la longueur de l'aperçu
    if (contentPreview.length > 60) {
      contentPreview = '${contentPreview.substring(0, 60)}...';
    }

    ReportDialog.show(
      context,
      contentType: ContentType.post,
      contentId: _post!.id,
      contentTitle: contentPreview,
    ).then((result) {
      if (result == true) {
        debugPrint('✅ Post ${_post!.id} signalé avec succès');
      }
    });
  }

  /// 🚩 SIGNALEMENT DE COMMENTAIRE - NOUVELLE IMPLÉMENTATION
  void _showReportCommentDialog(Comment comment) {
    // Construire l'aperçu du commentaire
    String contentPreview = comment.content;
    if (contentPreview.length > 60) {
      contentPreview = '${contentPreview.substring(0, 60)}...';
    }

    ReportDialog.show(
      context,
      contentType: ContentType.comment,
      contentId: comment.id,
      contentTitle: contentPreview,
    ).then((result) {
      if (result == true) {
        debugPrint('✅ Comment ${comment.id} signalé avec succès');
      }
    });
  }

  /// 📱 SNACKBAR
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// 🎨 GÉNÉRATION DE COULEUR DYNAMIQUE
  Color _generateBackgroundColor() {
    if (_post?.tags != null && _post!.tags.isNotEmpty) {
      final tag = _post!.tags.first.toLowerCase();
      switch (tag) {
        case 'fitness':
        case 'sport':
        case 'transformation':
          return const Color(0xFF4ECDC4); // Turquoise comme l'exemple
        case 'wellness':
        case 'health':
          return const Color(0xFF45B7D1); // Bleu
        case 'food':
        case 'nutrition':
          return const Color(0xFF96CEB4); // Vert
        case 'lifestyle':
        case 'life':
          return const Color(0xFFFECEA8); // Orange doux
        case 'morning':
        case 'routine':
          return const Color(0xFF667EEA); // Bleu violet
        default:
          return const Color(0xFF4ECDC4); // Turquoise par défaut
      }
    }
    return const Color(0xFF4ECDC4); // Turquoise par défaut
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _generateBackgroundColor(),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_post == null) {
      return _buildNotFoundState();
    }

    return Stack(
      children: [
        // Contenu principal
        _buildMainContent(),
        
        // Animation de like
        if (_showLikeAnimation) _buildLikeAnimation(),
        
        // Bottom sheet des commentaires
        if (_showCommentsSheet) _buildCommentsSheet(),
      ],
    );
  }

  /// ⏳ ÉTAT DE CHARGEMENT
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Chargement du post...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// ❌ ÉTAT D'ERREUR
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _generateBackgroundColor(),
            ),
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  /// 🚫 POST NON TROUVÉ
  Widget _buildNotFoundState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 64, color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Post non trouvé',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  /// 🎨 CONTENU PRINCIPAL
  Widget _buildMainContent() {
    return Stack(
      children: [
        // Image plein écran (parallax)
        _buildMainImage(),
        
        // AppBar en overlay
        _buildAppBar(),
        
        // Actions flottantes
        _buildFloatingActions(),
        
        // Section infos en bas (draggable)
        _buildBottomInfoSection(),
      ],
    );
  }

  /// 📱 APPBAR (EN OVERLAY)
  Widget _buildAppBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              
              const Spacer(),
              
              GestureDetector(
                onTap: _showOptionsMenu,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🖼️ IMAGE PRINCIPALE (PLEIN ÉCRAN PARALLAX)
  Widget _buildMainImage() {
    return Positioned.fill(
      child: GestureDetector(
        onDoubleTap: _handleLike,
        child: _post!.mediaUrl.isNotEmpty
            ? Stack(
                children: [
                  // Image plein écran
                  Positioned.fill(
                    child: Image.network(
                      _post!.mediaUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _generateBackgroundColor(),
                                _generateBackgroundColor().withOpacity(0.8),
                              ],
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Gradient overlay léger pour la lisibilité
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                          ],
                          stops: const [0.0, 0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      _generateBackgroundColor(),
                      _generateBackgroundColor().withOpacity(0.8),
                    ],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
      ),
    );
  }

  /// ⚡ ACTIONS FLOTTANTES
  Widget _buildFloatingActions() {
    return Consumer<PostsProvider>(
      builder: (context, postsProvider, _) {
        final isLiked = postsProvider.isLikedByUser(_post!.id);
        final likesCount = postsProvider.getLikesCount(_post!.id);
        
        return Positioned(
          right: 16,
          top: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            children: [
              // Like
              _buildFloatingAction(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.red : Colors.white,
                count: likesCount,
                onTap: _handleLike,
              ),
              
              const SizedBox(height: 20),
              
              // Commentaires
              _buildFloatingAction(
                icon: Icons.mode_comment_outlined,
                color: Colors.white,
                count: _comments.length,
                onTap: () {
                  setState(() {
                    _showCommentsSheet = true;
                  });
                },
              ),
              
              const SizedBox(height: 20),
              
              // Partage
              _buildFloatingAction(
                icon: Icons.share_outlined,
                color: Colors.white,
                onTap: () => _showSnackBar('Fonctionnalité de partage à venir !'),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🔘 ACTION FLOTTANTE
  Widget _buildFloatingAction({
    required IconData icon,
    required Color color,
    int? count,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            if (count != null && count > 0) ...[
              const SizedBox(height: 2),
              Text(
                _formatNumber(count),
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

  /// ❤️ ANIMATION DE LIKE
  Widget _buildLikeAnimation() {
    return Positioned.fill(
      child: Center(
        child: AnimatedBuilder(
          animation: _likeScaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _likeScaleAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 📋 SECTION INFOS EN BAS (DRAGGABLE)
  Widget _buildBottomInfoSection() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle pour drag
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                _buildAuthorInfo(),
                const SizedBox(height: 20),
                _buildPostTitle(),
                const SizedBox(height: 16),
                _buildPostContent(),
                const SizedBox(height: 16),
                _buildPostStats(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 👤 INFORMATIONS AUTEUR
  Widget _buildAuthorInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToUserProfile(_post!.userId, _post!.authorUsername),
            child: CircleAvatar(
              backgroundImage: NetworkImage(_post!.authorAvatarFallback),
              radius: 24,
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToUserProfile(_post!.userId, _post!.authorUsername),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post!.authorDisplayName.isNotEmpty 
                        ? _post!.authorDisplayName 
                        : _post!.authorUsername,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    'il y a ${_formatTimeAgo(_post!.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Bouton Suivre
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[600],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Suivre',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 TITRE ET DESCRIPTION DU POST
  Widget _buildPostTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_post!.title.isNotEmpty) ...[
            Text(
              _post!.title,
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_post!.description.isNotEmpty) ...[
            Text(
              _post!.description,
              style: const TextStyle(
                fontSize: 15,
                height: 1.4,
                color: Colors.black87,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 📝 CONTENU DU POST (TAGS UNIQUEMENT)
  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_post!.tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _post!.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _generateBackgroundColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _generateBackgroundColor().withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      color: _generateBackgroundColor(),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 📊 STATISTIQUES DU POST
  Widget _buildPostStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Icon(Icons.visibility, size: 16, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            '${_formatNumber(_post!.initialLikesCount + _post!.initialCommentsCount * 10)} vues',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            'Publié le ${_formatDate(_post!.createdAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 💬 SHEET COMMENTAIRES
  Widget _buildCommentsSheet() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showCommentsSheet = false;
          });
        },
        child: Container(
          color: Colors.black54,
          child: DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            'Commentaires (${_comments.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _showCommentsSheet = false;
                              });
                            },
                            icon: const Icon(Icons.close, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    
                    const Divider(),
                    
                    // Liste des commentaires
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return _buildCommentItem(comment);
                        },
                      ),
                    ),
                    
                    // Zone d'ajout de commentaire
                    _buildAddCommentSection(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 💬 ITEM COMMENTAIRE AVEC SIGNALEMENT
  Widget _buildCommentItem(Comment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateToUserProfile(comment.userId, comment.authorUsername),
            child: CircleAvatar(
              backgroundImage: NetworkImage(comment.authorAvatarFallback),
              radius: 16,
            ),
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToUserProfile(comment.userId, comment.authorUsername),
                            child: Text(
                              comment.authorDisplayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            comment.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Menu pour signaler le commentaire
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: Colors.grey[400],
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'profile':
                            _navigateToUserProfile(comment.userId, comment.authorUsername);
                            break;
                          case 'report':
                            _showReportCommentDialog(comment);
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'profile',
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 16, color: Colors.grey[700]),
                              const SizedBox(width: 8),
                              const Text('Voir le profil'),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag, size: 16, color: Colors.red[400]),
                              const SizedBox(width: 8),
                              Text('Signaler', style: TextStyle(color: Colors.red[400])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    fontSize: 14, 
                    height: 1.3,
                    color: Colors.black87,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✍️ SECTION AJOUT COMMENTAIRE
  Widget _buildAddCommentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[100]!, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(_post!.authorAvatarFallback),
            radius: 18,
          ),
          const SizedBox(width: 12),
          
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              decoration: InputDecoration(
                hintText: 'Ajouter un commentaire...',
                hintStyle: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.blue[400]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
              onSubmitted: (_) => _handleAddComment(),
            ),
          ),
          
          const SizedBox(width: 12),
          
          GestureDetector(
            onTap: _isAddingComment ? null : _handleAddComment,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue[600],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isAddingComment
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 16,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔧 MENU D'OPTIONS - MISE À JOUR AVEC SIGNALEMENT
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            // Titre
            Text(
              'Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            
            // Voir le profil
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: const Text('Voir le profil'),
              subtitle: Text('Profil de ${_post!.authorDisplayName}'),
              onTap: () {
                Navigator.pop(context);
                _navigateToUserProfile(_post!.userId, _post!.authorUsername);
              },
            ),
            
            // Partager
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.share, color: Colors.green),
              ),
              title: const Text('Partager'),
              subtitle: const Text('Partager ce post'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Fonctionnalité de partage à venir !');
              },
            ),
            
            // Signaler - NOUVEAU SYSTÈME
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.flag, color: Colors.red),
              ),
              title: const Text('Signaler', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Signaler ce contenu'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(); // ✅ NOUVEAU SYSTÈME
              },
            ),
            
            // Espace en bas
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${difference.inDays ~/ 7} semaine${difference.inDays ~/ 7 > 1 ? 's' : ''}';
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

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}