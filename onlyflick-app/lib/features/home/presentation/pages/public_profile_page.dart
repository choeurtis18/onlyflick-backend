// lib/features/user/presentation/pages/public_profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/models/user_models.dart';
import '../../../../core/services/user_service.dart';
import '../../../../features/auth/auth_provider.dart';

/// Page pour afficher le profil public d'un utilisateur avec statistiques
/// Permet de s'abonner si c'est un créateur
class PublicProfilePage extends StatefulWidget {
  final int userId;
  final String? username; // Optionnel pour l'affichage initial

  const PublicProfilePage({
    Key? key,
    required this.userId,
    this.username,
  }) : super(key: key);

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final UserService _userService = UserService();
  
  PublicUserProfile? _profile;
  SubscriptionStatus? _subscriptionStatus;
  
  // ===== NOUVEAU : État des posts =====
  List<UserPost> _posts = [];
  bool _isLoadingPosts = false;
  bool _hasMorePosts = false;
  int _currentPage = 1;
  String? _postsError;
  
  bool _isLoadingProfile = false;
  bool _isLoadingSubscription = false;
  bool _isSubscriptionAction = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Charge le profil public de l'utilisateur
  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _error = null;
    });

    final result = await _userService.getUserProfile(widget.userId);
    
    if (result.isSuccess && result.data != null) {
      setState(() {
        _profile = result.data!;
        _isLoadingProfile = false;
      });
      
      // Si c'est un créateur, charger le statut d'abonnement
      if (_profile!.isCreator) {
        _loadSubscriptionStatus();
      }
      
      // ===== NOUVEAU : Charger les posts après le profil =====
      _loadUserPosts();
    } else {
      setState(() {
        _error = result.error?.message ?? 'Erreur lors du chargement du profil';
        _isLoadingProfile = false;
      });
    }
  }

  /// Charge le statut d'abonnement pour un créateur
  Future<void> _loadSubscriptionStatus() async {
    if (!_profile!.isCreator) return;

    setState(() {
      _isLoadingSubscription = true;
    });

    final result = await _userService.checkSubscriptionStatus(widget.userId);
    
    if (result.isSuccess && result.data != null) {
      setState(() {
        _subscriptionStatus = result.data!;
        _isLoadingSubscription = false;
      });
    } else {
      setState(() {
        _isLoadingSubscription = false;
      });
      // Ne pas afficher d'erreur pour le statut d'abonnement, juste loguer
      debugPrint('Failed to load subscription status: ${result.error?.message}');
    }
  }

  /// ===== NOUVEAU : Charge les posts de l'utilisateur =====
  Future<void> _loadUserPosts({bool refresh = false}) async {
    if (_isLoadingPosts) return;

    setState(() {
      _isLoadingPosts = true;
      _postsError = null;
      if (refresh) {
        _posts.clear();
        _currentPage = 1;
      }
    });

    final result = await _userService.getUserPosts(
      widget.userId,
      page: refresh ? 1 : _currentPage,
      limit: 20,
    );

    if (result.isSuccess && result.data != null) {
      setState(() {
        if (refresh) {
          _posts = result.data!.posts;
        } else {
          _posts.addAll(result.data!.posts);
        }
        _hasMorePosts = result.data!.hasMore;
        _currentPage = refresh ? 2 : _currentPage + 1;
        _isLoadingPosts = false;
      });
      
      debugPrint('✅ Posts chargés: ${_posts.length} posts pour utilisateur ${widget.userId}');
    } else {
      setState(() {
        _postsError = result.error?.message ?? 'Erreur lors du chargement des posts';
        _isLoadingPosts = false;
      });
      
      debugPrint('❌ Erreur chargement posts: ${result.error?.message}');
    }
  }

  /// Gère l'abonnement/désabonnement
  Future<void> _handleSubscriptionAction() async {
    if (_profile == null || !_profile!.isCreator || _isSubscriptionAction) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isAuthenticated) {
      _showError('Vous devez être connecté pour vous abonner');
      return;
    }

    setState(() {
      _isSubscriptionAction = true;
    });

    try {
      UserServiceResult<String> result;
      
      if (_subscriptionStatus?.isActive == true) {
        // Se désabonner
        result = await _userService.unsubscribeFromCreator(widget.userId);
      } else {
        // S'abonner (sans paiement immédiat)
        result = await _userService.subscribeToCreator(widget.userId);
      }

      if (result.isSuccess) {
        // Afficher le message de succès
        _showSuccess(result.data ?? 'Action réussie');
        
        // Recharger le statut d'abonnement
        await _loadSubscriptionStatus();
      } else {
        _showError(result.error?.message ?? 'Erreur lors de l\'action');
      }
    } catch (e) {
      _showError('Erreur inattendue: $e');
    } finally {
      setState(() {
        _isSubscriptionAction = false;
      });
    }
  }

  /// Gère l'abonnement avec paiement
  Future<void> _handlePaymentSubscription() async {
    if (_profile == null || !_profile!.isCreator || _isSubscriptionAction) return;

    setState(() {
      _isSubscriptionAction = true;
    });

    try {
      final result = await _userService.subscribeWithPayment(widget.userId);
      
      if (result.isSuccess && result.data != null) {
        // Ici, on devrait intégrer Stripe pour finaliser le paiement
        // Pour l'instant, on montre juste le message
        final clientSecret = result.data!['client_secret'];
        _showSuccess('Paiement initié. Client Secret: $clientSecret');
        
        // Recharger le statut d'abonnement après paiement
        await _loadSubscriptionStatus();
      } else {
        _showError(result.error?.message ?? 'Erreur lors du paiement');
      }
    } catch (e) {
      _showError('Erreur lors du paiement: $e');
    } finally {
      setState(() {
        _isSubscriptionAction = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.username ?? 'Profil',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingProfile) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (_error != null) {
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
              _error!,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_profile == null) {
      return const Center(child: Text('Profil non trouvé'));
    }

    return RefreshIndicator(
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            // ===== NOUVEAU : Section des statistiques =====
            _buildUserStats(),
            const SizedBox(height: 24),
            if (_profile!.isCreator) ...[
              _buildSubscriptionSection(),
              const SizedBox(height: 24),
            ],
            _buildBioSection(),
            const SizedBox(height: 24),
            // ===== NOUVEAU : Section posts placeholder =====
            _buildUserPostsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        // Avatar
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey[300],
          backgroundImage: _profile!.avatarUrl != null
              ? NetworkImage(_profile!.avatarUrl!)
              : null,
          child: _profile!.avatarUrl == null
              ? Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.grey[600],
                )
              : null,
        ),
        const SizedBox(width: 16),
        
        // Informations utilisateur
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _profile!.displayName,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                '@${_profile!.username}',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              
              // Badge du rôle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _profile!.isCreator 
                      ? Colors.purple.withOpacity(0.1) 
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _profile!.isCreator ? Colors.purple : Colors.blue,
                    width: 1,
                  ),
                ),
                child: Text(
                  _profile!.isCreator ? '✨ Créateur' : '👤 Abonné',
                  style: TextStyle(
                    fontSize: 12,
                    color: _profile!.isCreator ? Colors.purple : Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ===== NOUVEAU : Section des statistiques utilisateur =====
  Widget _buildUserStats() {
    final stats = _profile!.stats;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            count: _profile!.postsCountFormatted,
            label: 'Posts',
            icon: Icons.grid_on,
          ),
          _buildStatDivider(),
          _buildStatItem(
            count: _profile!.followersCountFormatted,
            label: _profile!.isCreator ? 'Abonnés' : 'Followers',
            icon: Icons.people,
          ),
          _buildStatDivider(),
          _buildStatItem(
            count: _profile!.followingCountFormatted,
            label: 'Abonnements',
            icon: Icons.person_add,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String count,
    required String label,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.grey[600],
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          count,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }

  Widget _buildSubscriptionSection() {
    if (!_profile!.isCreator) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star, color: Colors.amber[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Abonnement',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_profile!.subscriptionPriceFormatted.isNotEmpty) ...[
            Text(
              _profile!.subscriptionPriceFormatted,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Statut d'abonnement et boutons
          if (_isLoadingSubscription)
            const Center(child: CircularProgressIndicator(color: Colors.black))
          else
            _buildSubscriptionButtons(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionButtons() {
    if (_subscriptionStatus == null) {
      // Statut inconnu, proposer l'abonnement
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubscriptionAction ? null : _handleSubscriptionAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('S\'abonner'),
            ),
          ),
        ],
      );
    }

    if (_subscriptionStatus!.isActive) {
      // Utilisateur abonné et actif
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Vous êtes abonné',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[800],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isSubscriptionAction ? null : _handleSubscriptionAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    )
                  : const Text('Se désabonner'),
            ),
          ),
        ],
      );
    } else {
      // Utilisateur non abonné ou abonnement inactif
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSubscriptionAction ? null : _handleSubscriptionAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('S\'abonner'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isSubscriptionAction ? null : _handlePaymentSubscription,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubscriptionAction
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text('S\'abonner avec paiement'),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildBioSection() {
    if (_profile!.bio == null || _profile!.bio!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey[400], size: 20),
            const SizedBox(width: 8),
            Text(
              'Aucune bio disponible',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'À propos',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _profile!.bio!,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  /// ===== NOUVEAU : Section des posts utilisateur avec vrais posts =====
  Widget _buildUserPostsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.grid_on,
                color: Colors.grey[600],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Publications',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Text(
                '${_profile?.stats.postsCount ?? 0}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Afficher les posts ou le state de chargement
          if (_isLoadingPosts && _posts.isEmpty)
            _buildPostsLoading()
          else if (_postsError != null)
            _buildPostsError()
          else if (_posts.isEmpty)
            _buildNoPosts()
          else
            _buildPostsList(),
        ],
      ),
    );
  }

  Widget _buildPostsLoading() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.black),
      ),
    );
  }

  Widget _buildPostsError() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red[400],
            ),
            const SizedBox(height: 8),
            Text(
              _postsError!,
              style: GoogleFonts.inter(
                color: Colors.red[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _loadUserPosts(refresh: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoPosts() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'Aucune publication',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cet utilisateur n\'a pas encore publié de contenu',
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList() {
    return Column(
      children: [
        // Grille des posts
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            final post = _posts[index];
            return _buildPostItem(post);
          },
        ),
        
        // Bouton charger plus si il y a plus de posts
        if (_hasMorePosts) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: _isLoadingPosts ? null : () => _loadUserPosts(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoadingPosts
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Text('Charger plus'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPostItem(UserPost post) {
    return GestureDetector(
      onTap: () {
        // TODO: Ouvrir le détail du post
        debugPrint('Clic sur post ${post.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image du post ou placeholder
              if (post.imageUrl != null)
                Image.network(
                  post.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildPostPlaceholder(post);
                  },
                )
              else
                _buildPostPlaceholder(post),
              
              // Overlay avec les infos
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Badge de visibilité
                      if (post.isSubscriberOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '🔒',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      
                      const Spacer(),
                      
                      // Nombre de likes
                      Row(
                        children: [
                          Icon(
                            post.isLiked ? Icons.favorite : Icons.favorite_border,
                            color: post.isLiked ? Colors.red : Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${post.likesCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostPlaceholder(UserPost post) {
    return Container(
      color: Colors.grey[300],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              post.hasMedia ? Icons.image : Icons.text_fields,
              color: Colors.grey[600],
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              post.formattedCreatedAt,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}