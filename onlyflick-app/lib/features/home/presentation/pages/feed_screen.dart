//lib/features/home/presentation/pages/feed_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../../features/auth/auth_provider.dart';
import '../../../../core/providers/posts_providers.dart';
import '../widgets/connected_post_widget.dart';
import '../pages/conversations_page.dart';

class FeedScreen extends StatefulWidget {
  final bool isCreator;
  final VoidCallback? onCreatePost;

  const FeedScreen({
    super.key, 
    this.isCreator = false,
    this.onCreatePost,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late PostsProvider _postsProvider;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    // Initialiser le provider après le premier frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postsProvider = context.read<PostsProvider>();
      _postsProvider.initializeFeed();
    });
    
    // Listener pour le scroll infini
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  //  Méthode pour détecter le scroll infini
  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      // Charger plus de posts quand on arrive à 80% du scroll
      _postsProvider.loadMorePosts();
    }
  }

  Future<void> _handleRefresh() async {
    await _postsProvider.refreshPosts();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Méthode ajoutée pour naviguer vers la messagerie
  void _navigateToMessages() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ConversationsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(),
            
            Expanded(
              child: Consumer<PostsProvider>(
                builder: (context, postsProvider, _) {
                  return RefreshIndicator(
                    onRefresh: _handleRefresh,
                    color: Colors.black,
                    backgroundColor: Colors.white,
                    child: _buildFeedContent(postsProvider),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        final isCreator = user?.isCreator == true;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              // Logo OnlyFlick
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'OnlyFlick',
                      style: GoogleFonts.pacifico(
                        fontSize: 28,
                        color: Colors.black,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purple, Colors.pink],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'BETA',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions à droite
              Row(
                children: [
                  if (isCreator) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple.withOpacity(0.1), Colors.pink.withOpacity(0.1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.purple[600]),
                          const SizedBox(width: 4),
                          Text(
                            'Créateur',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Bouton de création (pour les créateurs) - PLACÉ ICI
                  if (isCreator && widget.onCreatePost != null) ...[
                    GestureDetector(
                      onTap: widget.onCreatePost,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Bouton Messages 
                  GestureDetector(
                    onTap: _navigateToMessages,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.message_outlined, color: Colors.black, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Contenu du feed avec scroll infini
  Widget _buildFeedContent(PostsProvider postsProvider) {
    if (postsProvider.isLoading && !postsProvider.hasData) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.black,
        ),
      );
    }

    if (postsProvider.hasError && !postsProvider.hasData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              postsProvider.error ?? 'Une erreur est survenue',
              style: TextStyle(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => postsProvider.retry(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Réessayer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (!postsProvider.hasData) {
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
              'Aucun post à afficher',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Les posts apparaîtront ici',
              style: TextStyle(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Affichage des posts avec scroll infini
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      // Compter les posts + indicateur de refresh + indicateur de chargement
      itemCount: postsProvider.posts.length + 
                 (postsProvider.isRefreshing ? 1 : 0) + 
                 (postsProvider.hasMorePosts ? 1 : 0),
      itemBuilder: (context, index) {
        // Indicateur de chargement en haut pendant le refresh
        if (postsProvider.isRefreshing && index == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              ),
            ),
          );
        }

        // Ajuster l'index si on a l'indicateur de refresh
        final postIndex = postsProvider.isRefreshing ? index - 1 : index;
        
        // Indicateur de chargement en bas pour le scroll infini
        if (postIndex >= postsProvider.posts.length) {
          if (postsProvider.hasMorePosts) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Chargement...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            //  Message de fin de contenu
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 24,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vous avez tout vu !',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Revenez plus tard pour de nouveaux posts',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
        
        if (postIndex < 0 || postIndex >= postsProvider.posts.length) {
          return const SizedBox.shrink();
        }

        final post = postsProvider.posts[postIndex];
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ConnectedPostWidget(
            post: post,
            onLike: () => postsProvider.toggleLike(post.id),
            onComment: (content) => postsProvider.addComment(post.id, content),
            onError: (message) => _showSnackBar(message, isError: true),
          ),
        );
      },
    );
  }
}